#ifndef LUA_LDB_DRM_H
#define LUA_LDB_DRM_H


#include <xf86drm.h>
#include <xf86drmMode.h>

#define LDB_DRM_UDATA_NAME "DRM"

#define CHECK_DRM(L, I, D) D=(drm_t *)luaL_checkudata(L, I, LDB_DRM_UDATA_NAME); if ((D==NULL) || (D->fd<0)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a DRM device", I); return 2; }


/*
struct modeset_buf {
	uint32_t width;
	uint32_t height;
	uint32_t stride;
	uint32_t size;
	uint32_t handle;
	uint8_t *map;
	uint32_t fb;
};

struct modeset_dev {
	struct modeset_dev *next;

	unsigned int front_buf;
	struct modeset_buf bufs[2];

	drmModeModeInfo mode;
	uint32_t conn;
	uint32_t crtc;
	drmModeCrtc *saved_crtc;
};
*/

typedef struct {
    void* modeset_list;
	char* drmdev;
	int fd;
} drm_t;


#endif
