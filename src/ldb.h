#ifndef LUA_LDB_H
#define LUA_LDB_H


#include <stdint.h>

#define LDB_VERSION "3.0"
#define LDB_UDATA_NAME "drawbuffer"

#define LUA_LDB_CHECK_DB(L, I, D) D=(drawbuffer_t *)luaL_checkudata(L, I, LDB_UDATA_NAME); if ((D==NULL) || (!D->data)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a drawbuffer", I); return 2; }




typedef enum {
	LDB_PXFMT_1BPP_R,
	LDB_PXFMT_8BPP_R,
	LDB_PXFMT_8BPP_RGB332,
	LDB_PXFMT_16BPP_RGB565,
	LDB_PXFMT_16BPP_BGR565,
	LDB_PXFMT_24BPP_RGB,
	LDB_PXFMT_24BPP_BGR,
	LDB_PXFMT_32BPP_RGBA,
	LDB_PXFMT_32BPP_ARGB,
	LDB_PXFMT_32BPP_ABGR,
	LDB_PXFMT_32BPP_BGRA,
	LDB_PXFMT_MAX,
} PIX_FMT;

typedef struct {
    uint16_t w, h;
    void* data;
	PIX_FMT pxfmt;
} drawbuffer_t;

extern uint32_t ldb_get_px(drawbuffer_t*, int, int);
extern void ldb_set_px(drawbuffer_t*, int, int, uint8_t, uint8_t, uint8_t, uint8_t);


#endif
