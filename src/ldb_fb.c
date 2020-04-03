#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"
#include "ldb_fb.h"

#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/fb.h>
#include <string.h>
#include <stdlib.h>


#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);




static int lua_framebuffer_get_fixinfo(lua_State *L) {
	framebuffer_t *fb;
	CHECK_FRAMEBUFFER(L, 1, fb)

    lua_newtable(L);
    LUA_T_PUSH_S_S("id", fb->finfo.id)
    LUA_T_PUSH_S_N("smem_start", fb->finfo.smem_start)
    LUA_T_PUSH_S_N("type", fb->finfo.type)
    LUA_T_PUSH_S_N("type_aux", fb->finfo.type_aux)
    LUA_T_PUSH_S_N("visual", fb->finfo.visual)
    LUA_T_PUSH_S_N("xpanstep", fb->finfo.xpanstep)
    LUA_T_PUSH_S_N("ypanstep", fb->finfo.ypanstep)
    LUA_T_PUSH_S_N("ywrapstep", fb->finfo.ywrapstep)
    LUA_T_PUSH_S_N("line_length", fb->finfo.line_length)
    LUA_T_PUSH_S_N("mmio_start", fb->finfo.mmio_start)
    LUA_T_PUSH_S_N("mmio_len", fb->finfo.mmio_len)
    LUA_T_PUSH_S_N("accel", fb->finfo.accel)
    LUA_T_PUSH_S_N("capabilities", fb->finfo.capabilities)

    return 1;
}

static int lua_framebuffer_get_varinfo(lua_State *L) {
	framebuffer_t *fb;
	CHECK_FRAMEBUFFER(L, 1, fb)

    lua_newtable(L);
	LUA_T_PUSH_S_N("xres", fb->vinfo.xres)
    LUA_T_PUSH_S_N("yres", fb->vinfo.yres)
    LUA_T_PUSH_S_N("xres_virtual", fb->vinfo.xres_virtual)
    LUA_T_PUSH_S_N("yres_virtual", fb->vinfo.yres_virtual)
    LUA_T_PUSH_S_N("xoffset", fb->vinfo.xoffset)
    LUA_T_PUSH_S_N("yoffset", fb->vinfo.yoffset)
    LUA_T_PUSH_S_N("bits_per_pixel", fb->vinfo.bits_per_pixel)
    LUA_T_PUSH_S_N("grayscale", fb->vinfo.grayscale)
    LUA_T_PUSH_S_N("nonstd", fb->vinfo.nonstd)
    LUA_T_PUSH_S_N("activate", fb->vinfo.activate)
    LUA_T_PUSH_S_N("width", fb->vinfo.width)
    LUA_T_PUSH_S_N("height", fb->vinfo.height)
    LUA_T_PUSH_S_N("pixclock", fb->vinfo.pixclock)
    LUA_T_PUSH_S_N("left_margin", fb->vinfo.left_margin)
    LUA_T_PUSH_S_N("right_margin", fb->vinfo.right_margin)
    LUA_T_PUSH_S_N("upper_margin", fb->vinfo.upper_margin)
    LUA_T_PUSH_S_N("lower_margin", fb->vinfo.lower_margin)
    LUA_T_PUSH_S_N("hsync_len", fb->vinfo.hsync_len)
    LUA_T_PUSH_S_N("vsync_len", fb->vinfo.vsync_len)
    LUA_T_PUSH_S_N("sync", fb->vinfo.sync)
    LUA_T_PUSH_S_N("vmode", fb->vinfo.vmode)
    LUA_T_PUSH_S_N("rotate", fb->vinfo.rotate)
    LUA_T_PUSH_S_N("colorspace", fb->vinfo.colorspace)

    return 1;
}

static int lua_framebuffer_copy_from_db(lua_State *L) {
	framebuffer_t *fb;
	CHECK_FRAMEBUFFER(L, 1, fb)

	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 2, db)

	uint32_t sp;
	int cx,cy;
	int i;

	// TODO: Support other pixel packing formats(planes, etc.)
	if (fb->finfo.type != FB_TYPE_PACKED_PIXELS) {
		lua_pushnil(L);
		lua_pushfstring(L, "Only FB_TYPE_PACKED_PIXELS supported!", fb->vinfo.bits_per_pixel);
	}

	// TODO: Support drawbuffers with other dimensions
	if ((db->w != fb->vinfo.xres)  || (db->h != fb->vinfo.yres)) {
		lua_pushnil(L);
		lua_pushfstring(L, "Drawbuffer must be of dimensions %dx%d", fb->vinfo.xres, fb->vinfo.yres);
	}

	// TODO: Chech for correct pixel formats
	if ((fb->vinfo.bits_per_pixel == 32) && (db->pxfmt == LDB_PXFMT_32BPP_BGRA)) {
		size_t db_data_len = db->w*db->h*4;
		if (fb->finfo.smem_len >= db_data_len) {
			memcpy(fb->data, db->data, db_data_len);
		}
	} else if (fb->vinfo.bits_per_pixel == 32) {
		for (cy=0; cy < db->h; cy++) {
			for (cx=0; cx < db->w; cx++) {
				sp = ldb_get_px(db, cx,cy);
				// TODO: Support all pixel formats for the frambebuffer
				i = (cy*db->w+cx)*4;
				((uint8_t*)fb->data)[i] = (uint8_t)((sp&0x0000FF00)>>8);
				((uint8_t*)fb->data)[i+1] = (uint8_t)((sp&0x00FF0000)>>16);
				((uint8_t*)fb->data)[i+2] = (uint8_t)((sp&0xFF000000)>>24);
			}
		}
	} else {
		lua_pushnil(L);
		lua_pushfstring(L, "Only 16 & 32 bpp are supported, not: %d", fb->vinfo.bits_per_pixel);
		return 2;
	}

	return 0;
}

static int lua_framebuffer_close(lua_State *L) {
	framebuffer_t *fb = (framebuffer_t *)luaL_checkudata(L, 1, LDB_FB_UDATA_NAME);
	if (!fb) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a framebuffer");
		return 2;
	}

    if (fb->fd >= 0) {
        close(fb->fd);
        fb->fd = -1;
    }
	//if (fb->fbdev) {
	//	free(fb->fbdev);
	//	fb->fbdev = NULL;
	//}
	if (fb->data) {
		munmap(fb->data, fb->finfo.smem_len);
		fb->data = NULL;
	}

    return 0;
}

static int lua_framebuffer_tostring(lua_State *L) {
	framebuffer_t *fb = (framebuffer_t *)luaL_checkudata(L, 1, LDB_FB_UDATA_NAME);
	if (!fb) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a framebuffer");
		return 2;
	}

    if (fb->fd>=0) {
        lua_pushfstring(L, "Framebuffer: %s", fb->finfo.id);
    } else {
        lua_pushfstring(L, "Closed framebuffer");
    }

    return 1;
}



static int lua_fb_new_framebuffer(lua_State *L) {
	// get single argument
	size_t fbdev_len = 0;
	const char* fbdev = lua_tolstring(L, 1, &fbdev_len);
	if ((!fbdev) || (fbdev_len<1)) {
		lua_pushnil(L);
		lua_pushfstring(L, "First argument must be a device");
		return 2;
	}

	// put new userdata on stack
	framebuffer_t *fb = (framebuffer_t*)lua_newuserdata(L, sizeof(framebuffer_t));

	//fb->fbdev = strndup(char, fbdev_len);

	// open the framebuffer device in /dev
    fb->fd = open(fbdev, O_RDWR);
    if (fb->fd < 0) {
		lua_pushnil(L);
		lua_pushfstring(L, "Couldn't open framebuffer: %s", strerror(errno));
		return 2;
    }

	// perform ioctl's to get info about framebuffer
    if (ioctl(fb->fd, FBIOGET_FSCREENINFO, &fb->finfo)) {
		close(fb->fd);
		lua_pushnil(L);
		lua_pushfstring(L, "FBIOGET_FSCREENINFO failed: %s", strerror(errno));
		return 2;
	}
    if (ioctl(fb->fd, FBIOGET_VSCREENINFO, &fb->vinfo)) {
		close(fb->fd);
		lua_pushnil(L);
		lua_pushfstring(L, "FBIOGET_FSCREENINFO failed: %s", strerror(errno));
		return 2;
	}

	// mmap the pixel memory region
    fb->data = mmap(NULL, fb->finfo.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, (off_t)0);
	if (fb->data == MAP_FAILED) {
		close(fb->fd);
		lua_pushnil(L);
		lua_pushfstring(L, "mmap failed: %s", strerror(errno));
		return 2;
	}

	// push/create metatable for framebuffer userdata. The same metatable is used for every framebuffer instance.
    if (luaL_newmetatable(L, LDB_FB_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("get_fixinfo", lua_framebuffer_get_fixinfo)
		LUA_T_PUSH_S_CF("get_varinfo", lua_framebuffer_get_varinfo)
		LUA_T_PUSH_S_CF("copy_from_db", lua_framebuffer_copy_from_db)
		LUA_T_PUSH_S_CF("close", lua_framebuffer_close)
		LUA_T_PUSH_S_CF("tostring", lua_framebuffer_tostring)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_framebuffer_close)
		LUA_T_PUSH_S_CF("__tostring", lua_framebuffer_tostring)
	}

	// apply metatable to userdata
    lua_setmetatable(L, -2);

	// return userdata
    return 1;
}





LUALIB_API int luaopen_ldb_fb(lua_State *L) {
    lua_newtable(L);

    LUA_T_PUSH_S_S("version", LDB_VERSION)
    LUA_T_PUSH_S_CF("new_framebuffer", lua_fb_new_framebuffer)

    return 1;
}
