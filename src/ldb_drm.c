/* modeset - simple Lua binding to the modeset functionallity
 * Original code by David Rheinsberg <david.rheinsberg@gmail.com> (Dedicated to
 * the Public Domain.) */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#include "lua.h"
#include "lauxlib.h"
#include "ldb.h"
#include "ldb_drm.h"

#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);


struct modeset_dev {
	struct modeset_dev *next;

	uint32_t width;
	uint32_t height;
	uint32_t stride;
	uint32_t size;
	uint32_t handle;
	uint8_t *map;

	drmModeModeInfo mode;
	uint32_t fb;
	uint32_t conn;
	uint32_t crtc;
	drmModeCrtc *saved_crtc;
};

static struct modeset_dev *modeset_list = NULL;


static int modeset_find_crtc(int fd, drmModeRes *res, drmModeConnector *conn, struct modeset_dev *dev) {
	drmModeEncoder *enc;
	int i, j;
	int32_t crtc;
	struct modeset_dev *iter;

	/* first try the currently conected encoder+crtc */
	if (conn->encoder_id)
		enc = drmModeGetEncoder(fd, conn->encoder_id);
	else
		enc = NULL;

	if (enc) {
		if (enc->crtc_id) {
			crtc = enc->crtc_id;
			for (iter = modeset_list; iter; iter = iter->next) {
				if (iter->crtc == (uint32_t)crtc) {
					crtc = -1;
					break;
				}
			}

			if (crtc >= 0) {
				drmModeFreeEncoder(enc);
				dev->crtc = crtc;
				return 0;
			}
		}

		drmModeFreeEncoder(enc);
	}

	/* If the connector is not currently bound to an encoder or if the
	 * encoder+crtc is already used by another connector (actually unlikely
	 * but lets be safe), iterate all other available encoders to find a
	 * matching CRTC. */
	for (i = 0; i < conn->count_encoders; ++i) {
		enc = drmModeGetEncoder(fd, conn->encoders[i]);
		if (!enc) {
			//fprintf(stderr, "cannot retrieve encoder %u:%u (%d): %m\n", i, conn->encoders[i], errno);
			fprintf(stderr, "cannot retrieve encoder %u:%u (%d)\n", i, conn->encoders[i], errno);
			continue;
		}

		/* iterate all global CRTCs */
		for (j = 0; j < res->count_crtcs; ++j) {
			/* check whether this CRTC works with the encoder */
			if (!(enc->possible_crtcs & (1 << j)))
				continue;

			/* check that no other device already uses this CRTC */
			crtc = res->crtcs[j];
			for (iter = modeset_list; iter; iter = iter->next) {
				if (iter->crtc == (uint32_t)crtc) {
					crtc = -1;
					break;
				}
			}

			/* we have found a CRTC, so save it and return */
			if (crtc >= 0) {
				drmModeFreeEncoder(enc);
				dev->crtc = crtc;
				return 0;
			}
		}

		drmModeFreeEncoder(enc);
	}

	fprintf(stderr, "cannot find suitable CRTC for connector %u\n", conn->connector_id);
	return -ENOENT;
}

static int modeset_create_fb(int fd, struct modeset_dev *dev) {
	struct drm_mode_create_dumb creq;
	struct drm_mode_destroy_dumb dreq;
	struct drm_mode_map_dumb mreq;
	int ret;

	/* create dumb buffer */
	memset(&creq, 0, sizeof(creq));
	creq.width = dev->width;
	creq.height = dev->height;
	creq.bpp = 32;
	ret = drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq);
	if (ret < 0) {
		fprintf(stderr, "cannot create dumb buffer (%d)\n", errno);
		return -errno;
	}
	dev->stride = creq.pitch;
	dev->size = creq.size;
	dev->handle = creq.handle;

	/* create framebuffer object for the dumb-buffer */
	ret = drmModeAddFB(fd, dev->width, dev->height, 24, 32, dev->stride, dev->handle, &dev->fb);
	if (ret) {
		fprintf(stderr, "cannot create framebuffer (%d)\n", errno);
		ret = -errno;
		goto err_destroy;
	}

	/* prepare buffer for memory mapping */
	memset(&mreq, 0, sizeof(mreq));
	mreq.handle = dev->handle;
	ret = drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq);
	if (ret) {
		fprintf(stderr, "cannot map dumb buffer (%d)\n", errno);
		ret = -errno;
		goto err_fb;
	}

	/* perform actual memory mapping */
	dev->map = mmap(0, dev->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mreq.offset);
	if (dev->map == MAP_FAILED) {
		fprintf(stderr, "cannot mmap dumb buffer (%d)\n", errno);
		ret = -errno;
		goto err_fb;
	}

	/* clear the framebuffer to 0 */
	memset(dev->map, 0, dev->size);

	return 0;

err_fb:
	drmModeRmFB(fd, dev->fb);
err_destroy:
	memset(&dreq, 0, sizeof(dreq));
	dreq.handle = dev->handle;
	drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
	return ret;
}

static int modeset_setup_dev(int fd, drmModeRes *res, drmModeConnector *conn, struct modeset_dev *dev) {
	int ret;

	/* check if a monitor is connected */
	if (conn->connection != DRM_MODE_CONNECTED) {
		fprintf(stderr, "ignoring unused connector %u\n", conn->connector_id);
		return -ENOENT;
	}

	/* check if there is at least one valid mode */
	if (conn->count_modes == 0) {
		fprintf(stderr, "no valid mode for connector %u\n", conn->connector_id);
		return -EFAULT;
	}

	/* copy the mode information into our device structure */
	memcpy(&dev->mode, &conn->modes[0], sizeof(dev->mode));
	dev->width = conn->modes[0].hdisplay;
	dev->height = conn->modes[0].vdisplay;
	fprintf(stderr, "mode for connector %u is %ux%u\n", conn->connector_id, dev->width, dev->height);

	/* find a crtc for this connector */
	ret = modeset_find_crtc(fd, res, conn, dev);
	if (ret) {
		fprintf(stderr, "no valid crtc for connector %u\n", conn->connector_id);
		return ret;
	}

	/* create a framebuffer for this CRTC */
	ret = modeset_create_fb(fd, dev);
	if (ret) {
		fprintf(stderr, "cannot create framebuffer for connector %u\n", conn->connector_id);
		return ret;
	}

	return 0;
}

static int modeset_prepare(int fd) {
	drmModeRes *res;
	drmModeConnector *conn;
	int i;
	struct modeset_dev *dev;
	int ret;

	/* retrieve resources */
	res = drmModeGetResources(fd);
	if (!res) {
		//fprintf(stderr, "cannot retrieve DRM resources (%d): %m\n", errno);
		fprintf(stderr, "cannot retrieve DRM resources (%d)\n", errno);
		return -errno;
	}

	/* iterate all connectors */
	for (i = 0; i < res->count_connectors; ++i) {
		/* get information for each connector */
		conn = drmModeGetConnector(fd, res->connectors[i]);
		if (!conn) {
			//fprintf(stderr, "cannot retrieve DRM connector %u:%u (%d): %m\n", i, res->connectors[i], errno);
			fprintf(stderr, "cannot retrieve DRM connector %u:%u (%d)\n", i, res->connectors[i], errno);
			continue;
		}

		/* create a device structure */
		dev = malloc(sizeof(*dev));
		memset(dev, 0, sizeof(*dev));
		dev->conn = conn->connector_id;

		/* call helper function to prepare this connector */
		ret = modeset_setup_dev(fd, res, conn, dev);
		if (ret) {
			if (ret != -ENOENT) {
				errno = -ret;
				//fprintf(stderr, "cannot setup device for connector %u:%u (%d): %m\n", i, res->connectors[i], errno);
				fprintf(stderr, "cannot setup device for connector %u:%u (%d)\n", i, res->connectors[i], errno);
			}
			free(dev);
			drmModeFreeConnector(conn);
			continue;
		}

		/* free connector data and link device into global list */
		drmModeFreeConnector(conn);
		dev->next = modeset_list;
		modeset_list = dev;
	}

	/* free resources again */
	drmModeFreeResources(res);
	return 0;
}

static void modeset_cleanup(int fd) {
	struct modeset_dev *iter;
	struct drm_mode_destroy_dumb dreq;

	while (modeset_list) {
		/* remove from global list */
		iter = modeset_list;
		modeset_list = iter->next;

		/* restore saved CRTC configuration */
		drmModeSetCrtc(fd,
			       iter->saved_crtc->crtc_id,
			       iter->saved_crtc->buffer_id,
			       iter->saved_crtc->x,
			       iter->saved_crtc->y,
			       &iter->conn,
			       1,
			       &iter->saved_crtc->mode);
		drmModeFreeCrtc(iter->saved_crtc);

		/* unmap buffer */
		munmap(iter->map, iter->size);

		/* delete framebuffer */
		drmModeRmFB(fd, iter->fb);

		/* delete dumb buffer */
		memset(&dreq, 0, sizeof(dreq));
		dreq.handle = iter->handle;
		drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);

		/* free allocated memory */
		free(iter);
	}
}


void drm_card_drawbuffer_close(void* data) {
	drawbuffer_t *db = (drawbuffer_t*)data;
	drm_t *drm = db->close_data;

	if (drm->fd >= 0) {
        close(drm->fd);
        drm->fd = -1;
    }
	if (drm->modeset_list) {
		modeset_cleanup(drm->fd);
		drm->modeset_list = NULL;
	}
}

static int lua_drm_card_get_drawbuffer(lua_State *L) {
	drm_t *drm;
	CHECK_DRM(L, 1, drm)

	int list_entry_index = lua_tonumber(L, 2);

	struct modeset_dev *iter = NULL;
	struct modeset_dev *found = NULL;
	int i = 1;
	for (iter = modeset_list; iter; iter = iter->next) {
		if ((list_entry_index==i) && (iter->size!=get_data_size(iter->width, iter->height, LDB_PXFMT_32BPP_RGBA))) {
			found = iter;
			break;
		}
		i++;
	}
	if (found == NULL) {
		return 0;
	}

	// Create new drawbuffer userdata object
	drawbuffer_t *db = (drawbuffer_t *)lua_newuserdata(L, sizeof(drawbuffer_t));

	db->w = found->width;
	db->h = found->height;

	// TODO: Check pixel format and pitch from SDL surface for compabillity, maybe suppoprt all pixel formats supported by ldb.
	db->pxfmt = LDB_PXFMT_32BPP_BGRA;
	db->data = found->map;
	db->close_func = &drm_card_drawbuffer_close;
	db->close_data = drm;

	// apply the drawbuffer metatable to it
	lua_set_ldb_meta(L, -2);

	// return created drawbuffer
	return 1;
}


static int lua_drm_card_copy_from_db(lua_State *L) {
	drm_t *drm;
	CHECK_DRM(L, 1, drm)

	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 2, db)

	size_t db_len = get_data_size(db->pxfmt, db->w, db->h);

	int list_entry_index = lua_tonumber(L, 3);

	int i = 1;
	uint32_t sp;
	uint8_t r, g, b;
	struct modeset_dev *iter;
	for (iter = modeset_list; iter; iter = iter->next) {
		if ((list_entry_index==i) && (db_len == iter->size)) {
			// TODO: This just assumes same geometry/pixel format
			memcpy(iter->map, db->data, db_len);
			lua_pushboolean(L, 1);
			return 1;
		} else if (list_entry_index==i) {
			for (uint32_t y = 0; y < iter->height; ++y) {
				for (uint32_t x = 0; x < iter->width; ++x) {
					sp = get_px(db->data, db->w, x,y, db->pxfmt);
					UNPACK_RGB(sp, r,g,b)
					*(uint32_t*)&iter->map[iter->stride * y + x * 4] = (r << 16) | (g << 8) | b;
				}
			}
			lua_pushboolean(L, 1);
			return 1;
		}
		i++;
	}

	return 0;
}



static int lua_drm_card_get_info(lua_State *L) {
	drm_t *drm;
	CHECK_DRM(L, 1, drm)

    lua_newtable(L);

	struct modeset_dev *iter;
	int table_index = 1;
	for (iter = modeset_list; iter; iter = iter->next) {
		lua_pushnumber(L, table_index);
		lua_newtable(L);

		LUA_T_PUSH_S_N("width", iter->width)
		LUA_T_PUSH_S_N("height", iter->height)
		LUA_T_PUSH_S_N("stride", iter->stride)
		LUA_T_PUSH_S_N("size", iter->size)
		LUA_T_PUSH_S_N("handle", iter->handle)
		LUA_T_PUSH_S_N("conn", iter->conn)
		LUA_T_PUSH_S_N("crtc", iter->crtc)

		lua_pushstring(L, "mode");
		lua_newtable(L);
		LUA_T_PUSH_S_N("clock", iter->mode.clock)
		LUA_T_PUSH_S_N("hdisplay", iter->mode.hdisplay)
		LUA_T_PUSH_S_N("hsync_start", iter->mode.hsync_start)
		LUA_T_PUSH_S_N("hsync_end", iter->mode.hsync_end)
		LUA_T_PUSH_S_N("htotal", iter->mode.htotal)
		LUA_T_PUSH_S_N("hskew", iter->mode.hskew)
		LUA_T_PUSH_S_N("vdisplay", iter->mode.vdisplay)
		LUA_T_PUSH_S_N("vsync_start", iter->mode.vsync_start)
		LUA_T_PUSH_S_N("vsync_end", iter->mode.vsync_end)
		LUA_T_PUSH_S_N("vtotal", iter->mode.vtotal)
		LUA_T_PUSH_S_N("vscan", iter->mode.vscan)
		LUA_T_PUSH_S_N("vrefresh", iter->mode.vrefresh)
		LUA_T_PUSH_S_N("flags", iter->mode.flags)
		LUA_T_PUSH_S_N("type", iter->mode.type)
		LUA_T_PUSH_S_S("name", iter->mode.name)
		lua_settable(L, -3);

		lua_settable(L, -3);
		table_index++;
	}

    return 1;
}


static int lua_drm_card_prepare(lua_State *L) {
	drm_t *card;
	CHECK_DRM(L, 1, card)

	// prepare all connectors and CRTCs
	int ret = modeset_prepare(card->fd);
	if (ret) {
		errno = -ret;
		close(card->fd);
		lua_pushnil(L);
		lua_pushfstring(L, "modeset prepare failed with error %d: %m\n", errno);
		return 2;
	}

	// perform actual modesetting on each found connector+CRTC
	struct modeset_dev *iter;
	for (iter = modeset_list; iter; iter = iter->next) {
		iter->saved_crtc = drmModeGetCrtc(card->fd, iter->crtc); // save current mode
		if (drmModeSetCrtc(card->fd, iter->crtc, iter->fb, 0, 0, &iter->conn, 1, &iter->mode)) {
			close(card->fd);
			lua_pushnil(L);
			lua_pushfstring(L, "cannot set CRTC for connector %u (%d): %m\n", iter->conn, errno);
			return 2;
		}
	}

	lua_pushboolean(L, 1);
	return 1;
}


static int lua_drm_card_close(lua_State *L) {
	drm_t *drm = (drm_t *)luaL_checkudata(L, 1, LDB_DRM_UDATA_NAME);
	if (!drm) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a DRM device");
		return 2;
	}

    if (drm->fd >= 0) {
        close(drm->fd);
        drm->fd = -1;
    }
	if (drm->modeset_list) {
		modeset_cleanup(drm->fd);
		drm->modeset_list = NULL;
	}

    return 0;
}


static int lua_drm_card_tostring(lua_State *L) {
	drm_t *drm = (drm_t *)luaL_checkudata(L, 1, LDB_DRM_UDATA_NAME);
	if (!drm) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a DRM device");
		return 2;
	}

    if (drm->fd>=0) {
        lua_pushfstring(L, "DRM: %s(fd %d)", drm->drmdev, drm->fd);
    } else {
        lua_pushfstring(L, "DRM: (closed)");
    }

    return 1;
}


static int lua_drm_new_card(lua_State *L) {
	uint64_t has_dumb;
	const char* drmdev;
	size_t drmdev_len = 0;
	drm_t *card;

	// get single argument
	drmdev = lua_tolstring(L, 1, &drmdev_len);
	if ((!drmdev) || (drmdev_len<1)) {
		lua_pushnil(L);
		lua_pushfstring(L, "First argument must be a device");
		return 2;
	}

	// put new userdata on stack
	card = (drm_t*)lua_newuserdata(L, sizeof(drm_t));
	card->drmdev = strndup(drmdev, drmdev_len);

	// open the DRM device
	card->fd = open(drmdev, O_RDWR);
	if (card->fd < 0) {
		lua_pushnil(L);
		lua_pushfstring(L, "cannot open card '%s': %m\n", drmdev);
		return 2;
	}

	// Check for the required DRM_CAP_DUMB_BUFFER capabillity
	if (drmGetCap(card->fd, DRM_CAP_DUMB_BUFFER, &has_dumb) < 0 || !has_dumb) {
		lua_pushnil(L);
		lua_pushfstring(L, "card '%s' does not support dumb buffers\n", drmdev);
		close(card->fd);
		return 2;
	}

	// push/create metatable for drm userdata. The same metatable is used for every drm instance.
    if (luaL_newmetatable(L, LDB_DRM_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("prepare", lua_drm_card_prepare)
		LUA_T_PUSH_S_CF("get_info", lua_drm_card_get_info)
		LUA_T_PUSH_S_CF("copy_from_db", lua_drm_card_copy_from_db)
		LUA_T_PUSH_S_CF("get_drawbuffer", lua_drm_card_get_drawbuffer)
		LUA_T_PUSH_S_CF("close", lua_drm_card_close)
		LUA_T_PUSH_S_CF("tostring", lua_drm_card_tostring)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_drm_card_close)
		LUA_T_PUSH_S_CF("__tostring", lua_drm_card_tostring)
	}

	// apply metatable to userdata
    lua_setmetatable(L, -2);

	// return userdata
    return 1;
}


LUALIB_API int luaopen_ldb_drm(lua_State *L) {
    lua_newtable(L);

    LUA_T_PUSH_S_S("version", LDB_VERSION)
    LUA_T_PUSH_S_CF("new_card", lua_drm_new_card)

    return 1;
}
