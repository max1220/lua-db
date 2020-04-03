#ifndef LUA_LDB_FB_H
#define LUA_LDB_FB_H


#include <linux/fb.h>

#define LDB_FB_UDATA_NAME "sdl2fb"

#define CHECK_FRAMEBUFFER(L, I, D) D=(framebuffer_t *)luaL_checkudata(L, I, LDB_FB_UDATA_NAME); if ((D==NULL) || (fb->fd<0)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a framebuffer", I); return 2; }



typedef struct {
    int fd;
    struct fb_fix_screeninfo finfo;
    struct fb_var_screeninfo vinfo;
    //char *fbdev;
    uint8_t *data;
} framebuffer_t;


#endif
