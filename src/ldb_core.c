#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"


#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_I_S(N, S) lua_pushinteger(L, N); lua_pushstring(L, S); lua_settable(L, -3);



static inline size_t get_data_size(PIX_FMT fmt, int w, int h) {
	switch (fmt) {
		case LDB_PXFMT_1BPP_R:
			return (w*h)/8;
		case LDB_PXFMT_8BPP_R:
		case LDB_PXFMT_8BPP_RGB332:
			return w*h;
		case LDB_PXFMT_16BPP_RGB565:
		case LDB_PXFMT_16BPP_BGR565:
			return w*h*2;
		case LDB_PXFMT_24BPP_RGB:
		case LDB_PXFMT_24BPP_BGR:
			return w*h*3;
		case LDB_PXFMT_32BPP_RGBA:
		case LDB_PXFMT_32BPP_ARGB:
		case LDB_PXFMT_32BPP_ABGR:
		case LDB_PXFMT_32BPP_BGRA:
			return w*h*4;
		default:
			return 0;
	}
}

static inline void set_px_1bpp_r(drawbuffer_t* db, int x, int y, uint8_t v) {
	uint8_t j = ((uint8_t*)db->data)[(y*db->w+x)/8];
	uint8_t i = 1<<(x%8);
	if (v) {
		j = j | i;
	} else {
		j = j & (~i);
	}
	((uint8_t*)db->data)[(y*db->w+x)/8] = j;
}

static inline void set_px_8bpp_r(drawbuffer_t* db, int x, int y, uint8_t v) {
	((uint8_t*)db->data)[y*db->w+x] = v;
}

static inline void set_px_8bpp_rgb332(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b) {
	uint8_t v = (r&0xe0) | ((g&0xe0)>>3) | ((b&0xc0)>>6);
	((uint8_t*)db->data)[y*db->w+x] = v;
}


static inline void set_px_16bpp_rgb565(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b) {
	uint16_t v = (((uint16_t)(r&0xF8))<<8) | (((uint16_t)(g&0xFC))<<3) | (((uint16_t)(b&0xF8))>>3);
	((uint16_t*)db->data)[y*db->w+x] = v;
}

static inline void set_px_16bpp_bgr565(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b) {
	uint16_t v = (((uint16_t)(r&0xF8))>>3) | (((uint16_t)(b&0xF8))<<8) | (((uint16_t)(g&0xFC))<<3);
	((uint16_t*)db->data)[y*db->w+x] = v;
}


static inline void set_px_24bpp_rgb(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b) {
	((uint8_t*)db->data)[(y*db->w+x)*3] = r;
	((uint8_t*)db->data)[(y*db->w+x)*3+1] = g;
	((uint8_t*)db->data)[(y*db->w+x)*3+2] = b;
}

static inline void set_px_24bpp_bgr(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b) {
	((uint8_t*)db->data)[(y*db->w+x)*3] = b;
	((uint8_t*)db->data)[(y*db->w+x)*3+1] = g;
	((uint8_t*)db->data)[(y*db->w+x)*3+2] = r;
}


static inline void set_px_32bpp_rgba(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	((uint8_t*)db->data)[(y*db->w+x)*4] = r;
	((uint8_t*)db->data)[(y*db->w+x)*4+1] = g;
	((uint8_t*)db->data)[(y*db->w+x)*4+2] = b;
	((uint8_t*)db->data)[(y*db->w+x)*4+3] = a;
}

static inline void set_px_32bpp_argb(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	((uint8_t*)db->data)[(y*db->w+x)*4] = a;
	((uint8_t*)db->data)[(y*db->w+x)*4+1] = r;
	((uint8_t*)db->data)[(y*db->w+x)*4+2] = g;
	((uint8_t*)db->data)[(y*db->w+x)*4+3] = b;
}

static inline void set_px_32bpp_abgr(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	((uint8_t*)db->data)[(y*db->w+x)*4] = a;
	((uint8_t*)db->data)[(y*db->w+x)*4+1] = b;
	((uint8_t*)db->data)[(y*db->w+x)*4+2] = g;
	((uint8_t*)db->data)[(y*db->w+x)*4+3] = r;
}

static inline void set_px_32bpp_bgra(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	((uint8_t*)db->data)[(y*db->w+x)*4] = b;
	((uint8_t*)db->data)[(y*db->w+x)*4+1] = g;
	((uint8_t*)db->data)[(y*db->w+x)*4+2] = r;
	((uint8_t*)db->data)[(y*db->w+x)*4+3] = a;
}


void ldb_set_px(drawbuffer_t* db, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	if ((x<0) || (y<0) || (x>=db->w) || (y>=db->h) || (!db->data)) {
		return;
	}
	switch (db->pxfmt) {
		case LDB_PXFMT_1BPP_R:
			set_px_1bpp_r(db, x, y, r);
			break;
		case LDB_PXFMT_8BPP_R:
			set_px_8bpp_r(db, x, y, r);
			break;
		case LDB_PXFMT_8BPP_RGB332:
			set_px_8bpp_rgb332(db, x, y, r, g, b);
			break;
		case LDB_PXFMT_16BPP_RGB565:
			set_px_16bpp_rgb565(db, x, y, r, g, b);
			break;
		case LDB_PXFMT_16BPP_BGR565:
			set_px_16bpp_bgr565(db, x, y, r, g, b);
			break;
		case LDB_PXFMT_24BPP_RGB:
			set_px_24bpp_rgb(db, x, y, r, g, b);
			break;
		case LDB_PXFMT_24BPP_BGR:
			set_px_24bpp_rgb(db, x, y, r, g, b);
			break;
		case LDB_PXFMT_32BPP_RGBA:
			set_px_32bpp_rgba(db, x, y, r, g, b, a);
			break;
		case LDB_PXFMT_32BPP_ARGB:
			set_px_32bpp_argb(db, x, y, r, g, b, a);
			break;
		case LDB_PXFMT_32BPP_ABGR:
			set_px_32bpp_abgr(db, x, y, r, g, b, a);
			break;
		case LDB_PXFMT_32BPP_BGRA:
			set_px_32bpp_bgra(db, x, y, r, g, b, a);
			break;
		default:
			break;
	}
}



static inline uint32_t get_px_1bpp_r(drawbuffer_t* db, int x, int y) {
	uint8_t j = ((uint8_t*)db->data)[(y*db->w+x)/8];
	if (j&(1<<(x&7))) {
		return 0xffffffff;
	} else {
		return 0x000000ff;
	}
}

static inline uint32_t get_px_8bpp_r(drawbuffer_t* db, int x, int y) {
	uint8_t v = ((uint8_t*)db->data)[y*db->w+x];
	return (((uint32_t)v)<<24) | (((uint32_t)v)<<16) | (((uint32_t)v)<<8) | 0xff;
}

static inline uint32_t get_px_8bpp_rgb332(drawbuffer_t* db, int x, int y) {
	uint8_t v = ((uint8_t*)db->data)[y*db->w+x];
	return (((uint32_t)(v&0xe0))<<24) | (((uint32_t)(v&0x1c))<<19) | (((uint32_t)(v&0x03))<<14) | 0xff;
}


static inline uint32_t get_px_16bpp_rgb565(drawbuffer_t* db, int x, int y) {
	uint16_t j = ((uint16_t*)db->data)[y*db->w+x];
	uint32_t v = 0x000000FF;
	v |= (uint32_t)(j&0xf800)<<16;
	v |= (uint32_t)(j&0x07E0)<<13;
	v |= (uint32_t)(j&0x001f)<<11;
	return v;
}

static inline uint32_t get_px_16bpp_bgr565(drawbuffer_t* db, int x, int y) {
	uint16_t j = ((uint16_t*)db->data)[y*db->w+x];
	uint32_t v = 0x000000FF;
	v |= (uint32_t)(j&0xf800);
	v |= (uint32_t)(j&0x07E0)<<13;
	v |= (uint32_t)(j&0x001f)<<27;
	return v;
}


static inline uint32_t get_px_24bpp_rgb(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x000000FF;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3])<<24;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3+1])<<16;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3+2])<<8;
	return v;
}

static inline uint32_t get_px_24bpp_bgr(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x000000FF;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3+2])<<24;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3+1])<<16;
	v |= (uint8_t)(((uint8_t*)db->data)[(y*db->w+x)*3])<<8;
	return v;
}


static inline uint32_t get_px_32bpp_rgba(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x00000000;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4])<<24;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+1])<<16;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+2])<<8;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+3]);
	return v;
}

static inline uint32_t get_px_32bpp_argb(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x00000000;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4]);
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+1])<<24;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+2])<<16;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+3])<<8;
	return v;
}

static inline uint32_t get_px_32bpp_abgr(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x00000000;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4]);
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+1])<<8;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+2])<<16;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+3])<<24;
	return v;
}

static inline uint32_t get_px_32bpp_bgra(drawbuffer_t* db, int x, int y) {
	uint32_t v = 0x00000000;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4])<<8;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+1])<<16;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+2])<<24;
	v |= (uint32_t)(((uint8_t*)db->data)[(y*db->w+x)*4+3]);
	return v;
}


uint32_t ldb_get_px(drawbuffer_t* db, int x, int y) {
	if ((x<0) || (y<0) || (x>=db->w) || (y>=db->h) || (!db->data)) {
		return 0;
	}
	switch (db->pxfmt) {
		case LDB_PXFMT_1BPP_R:
			return get_px_1bpp_r(db, x, y);
		case LDB_PXFMT_8BPP_R:
			return get_px_8bpp_r(db, x, y);
		case LDB_PXFMT_8BPP_RGB332:
			return get_px_8bpp_rgb332(db, x, y);
		case LDB_PXFMT_16BPP_RGB565:
			return get_px_16bpp_rgb565(db, x, y);
		case LDB_PXFMT_16BPP_BGR565:
			return get_px_16bpp_bgr565(db, x, y);
		case LDB_PXFMT_24BPP_RGB:
			return get_px_24bpp_rgb(db, x, y);
		case LDB_PXFMT_24BPP_BGR:
			return get_px_24bpp_rgb(db, x, y);
		case LDB_PXFMT_32BPP_RGBA:
			return get_px_32bpp_rgba(db, x, y);
		case LDB_PXFMT_32BPP_ARGB:
			return get_px_32bpp_argb(db, x, y);
		case LDB_PXFMT_32BPP_ABGR:
			return get_px_32bpp_abgr(db, x, y);
		case LDB_PXFMT_32BPP_BGRA:
			return get_px_32bpp_bgra(db, x, y);
		default:
			return 0;
	}
}



static int lua_drawbuffer_tostring(lua_State *L) {
	// return a string with info about the drawbuffer to Lua
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	if (!db->data) {
		lua_pushstring(L, "Closed Drawbuffer");
		return 1;
	}

	switch (db->pxfmt) {
		case LDB_PXFMT_1BPP_R:
			lua_pushfstring(L, "1bpp R Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_8BPP_R:
			lua_pushfstring(L, "8bpp R Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_8BPP_RGB332:
			lua_pushfstring(L, "8bpp RGB332 Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_16BPP_RGB565:
			lua_pushfstring(L, "16bpp RGB565 Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_16BPP_BGR565:
			lua_pushfstring(L, "16bpp BGR565 Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_24BPP_RGB:
			lua_pushfstring(L, "24bpp RGB Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_24BPP_BGR:
			lua_pushfstring(L, "24bpp BGR Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_32BPP_RGBA:
			lua_pushfstring(L, "32bpp RGBA Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_32BPP_ARGB:
			lua_pushfstring(L, "32bpp ARGB Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_32BPP_ABGR:
			lua_pushfstring(L, "32bpp ABGR Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_32BPP_BGRA:
			lua_pushfstring(L, "32bpp BGRA Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		default:
			return 0;
	}
}

static int lua_drawbuffer_bytelen(lua_State *L) {
	// return length of pixel data in bytes to Lua
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, get_data_size(db->pxfmt, db->w, db->h));
	return 1;
}

static int lua_drawbuffer_width(lua_State *L) {
	// return the width of a drawbuffer to Lua
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, db->w);

	return 1;
}

static int lua_drawbuffer_height(lua_State *L) {
	// return the height of a drawbuffer to Lua
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, db->h);

	return 1;
}

static int lua_drawbuffer_pixel_format(lua_State *L) {
	// return the pixel format as a string
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	const char* str;

	switch(db->pxfmt) {
		case LDB_PXFMT_1BPP_R:
			str = "r1";
			break;
		case LDB_PXFMT_8BPP_R:
			str = "r8";
			break;
		case LDB_PXFMT_8BPP_RGB332:
			str = "rgb332";
			break;
		case LDB_PXFMT_16BPP_RGB565:
			str = "rgb565";
			break;
		case LDB_PXFMT_16BPP_BGR565:
			str = "bgr565";
			break;
		case LDB_PXFMT_24BPP_RGB:
			str = "rgb888";
			break;
		case LDB_PXFMT_24BPP_BGR:
			str = "bgr888";
			break;
		case LDB_PXFMT_32BPP_RGBA:
			str = "rgba8888";
			break;
		case LDB_PXFMT_32BPP_ARGB:
			str = "argb8888";
			break;
		case LDB_PXFMT_32BPP_ABGR:
			str = "abgr8888";
			break;
		case LDB_PXFMT_32BPP_BGRA:
			str = "bgra8888";
			break;
		default:
			str = "";
			break;
	}

	lua_pushstring(L, str);
	return 1;
}

static int lua_drawbuffer_close(lua_State *L) {
	// close an instance of a drawbuffer, calling free() on the allocated
	// memory, if needed. Automatically called by the Lua GC
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	if (db->data) {
		free(db->data);
		db->data = NULL;
	}

	return 0;
}


static int lua_drawbuffer_get_px(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	if (!lua_isnumber(L, 2) || !lua_isnumber(L, 3)) {
		return 0;
	}

	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);

	uint32_t px = ldb_get_px(db, x,y);

	lua_pushinteger(L, (px&0xff000000)>>24);
	lua_pushinteger(L, (px&0x00ff0000)>>16);
	lua_pushinteger(L, (px&0x0000ff00)>>8);
	lua_pushinteger(L, px&0xff);

	return 4;
}

static int lua_drawbuffer_set_px(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	if (!lua_isnumber(L, 2) || !lua_isnumber(L, 3)) {
		return 0;
	}

	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);

	int r = lua_tointeger(L, 4);
	int g = lua_tointeger(L, 5);
	int b = lua_tointeger(L, 6);
	int a = lua_tointeger(L, 7);

	if (r>255 || g>255 || b>255 || a>255 || r<0 || g<0 || b<0 || a<0 ) {
		return 0;
	}

	ldb_set_px(db, x,y,r,g,b,a);

	return 0;
}

static int lua_drawbuffer_clear(lua_State *L) {
	// clear the drawbuffer in a uniform color
	drawbuffer_t *db = (drawbuffer_t *)lua_touserdata(L, 1);
	LUA_LDB_CHECK_DB(L, 1, db)

	int r = lua_tointeger(L, 2);
	int g = lua_tointeger(L, 3);
	int b = lua_tointeger(L, 4);
	int a = lua_tointeger(L, 5);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		return 0;
	}

	//TODO: Fastpath using memset
	for (int y = 0; y < db->h; y++) {
		for (int x = 0; x < db->w; x++) {
			ldb_set_px(db, x, y, r, g, b, a);
		}
	}

	return 0;
}


static int lua_drawbuffer_dump_data(lua_State *L) {
	drawbuffer_t *db = (drawbuffer_t *)lua_touserdata(L, 1);
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushlstring(L, (char*)db->data, get_data_size(db->pxfmt, db->w, db->h));
	return 1;
}

static int lua_drawbuffer_load_data(lua_State *L) {
	drawbuffer_t *db = (drawbuffer_t *)lua_touserdata(L, 1);
	LUA_LDB_CHECK_DB(L, 1, db)

	size_t data_len = get_data_size(db->pxfmt, db->w, db->h);

	size_t str_len = 0;
	const char* str = lua_tolstring(L, 2, &str_len);
	if ((!str) || (str_len != data_len)) {
		lua_pushnil(L);
		lua_pushfstring(L, "Argument 2 must be a string of length %d(is %d)", data_len, str_len);
		return 2;
	}

	memcpy(db->data, str, data_len);

	return 0;
}



static int lua_new_drawbuffer(lua_State *L) {

	// Check if we have width and height
	if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 and 2 need to be width and height!");
		return 2;
	}

	// create a new drawbuffer instance of the specified width, height
	int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);

	if ((w<0) || (h<0)) {
		lua_pushnil(L);
		lua_pushstring(L, "width and height need to be >0");
		return 2;
	}


	// check for pixel format argument(default rgba)
	PIX_FMT fmt = LDB_PXFMT_32BPP_RGBA;
	if (lua_isnumber(L, 3)) {
		fmt = lua_tointeger(L, 3);
		if (fmt >= LDB_PXFMT_MAX) {
			lua_pushnil(L);
			lua_pushstring(L, "Unknown format!");
			return 2;
		}
	}

	// determine length of pixel buffer
	size_t len = get_data_size(fmt, w, h);


	// Create new userdata object
	drawbuffer_t *db = (drawbuffer_t *)lua_newuserdata(L, sizeof(drawbuffer_t));

	// Allocate space for pixels
	db->data = malloc(len);

	// Check if we allocated memory
	if (db->data == NULL) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't allocate memory!");
		return 2;
	}

	// store info about drawbuffer in drawbuffer
	db->w = w;
	db->h = h;
	db->pxfmt = fmt;

	// push/create metatable for userdata. The same metatable is used for every drawbuffer instance.
	if (luaL_newmetatable(L, LDB_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("width", lua_drawbuffer_width)
		LUA_T_PUSH_S_CF("height", lua_drawbuffer_height)
		LUA_T_PUSH_S_CF("bytes_len", lua_drawbuffer_bytelen)
		LUA_T_PUSH_S_CF("pixel_format", lua_drawbuffer_pixel_format)
		LUA_T_PUSH_S_CF("get_px", lua_drawbuffer_get_px)
		LUA_T_PUSH_S_CF("set_px", lua_drawbuffer_set_px)
		LUA_T_PUSH_S_CF("clear", lua_drawbuffer_clear)
		LUA_T_PUSH_S_CF("dump_data", lua_drawbuffer_dump_data)
		LUA_T_PUSH_S_CF("load_data", lua_drawbuffer_load_data)
		LUA_T_PUSH_S_CF("close", lua_drawbuffer_close)
		LUA_T_PUSH_S_CF("tostring", lua_drawbuffer_tostring)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_drawbuffer_close)
		LUA_T_PUSH_S_CF("__tostring", lua_drawbuffer_tostring)
	}

	// apply metatable to userdata
	lua_setmetatable(L, -2);

	// return userdata
	return 1;
}


// when the module is require()'ed, return a table with the new_drawbuffer function, and some constants
LUALIB_API int luaopen_ldb_core(lua_State *L) {
	lua_newtable(L);

	LUA_T_PUSH_S_S("version", LDB_VERSION)
	LUA_T_PUSH_S_CF("new_drawbuffer", lua_new_drawbuffer)

	lua_pushstring(L, "pixel_formats");
	lua_newtable(L);
	LUA_T_PUSH_S_I("r1", LDB_PXFMT_1BPP_R)
	LUA_T_PUSH_S_I("r8", LDB_PXFMT_8BPP_R)
	LUA_T_PUSH_S_I("rgb332", LDB_PXFMT_8BPP_RGB332)
	LUA_T_PUSH_S_I("rgb565", LDB_PXFMT_16BPP_RGB565)
	LUA_T_PUSH_S_I("bgr565", LDB_PXFMT_16BPP_BGR565)
	LUA_T_PUSH_S_I("rgb888", LDB_PXFMT_24BPP_RGB)
	LUA_T_PUSH_S_I("bgr888", LDB_PXFMT_24BPP_BGR)
	LUA_T_PUSH_S_I("rgba8888", LDB_PXFMT_32BPP_RGBA)
	LUA_T_PUSH_S_I("argb8888", LDB_PXFMT_32BPP_ARGB)
	LUA_T_PUSH_S_I("abgr8888", LDB_PXFMT_32BPP_ABGR)
	LUA_T_PUSH_S_I("bgra8888", LDB_PXFMT_32BPP_BGRA)

	lua_settable(L, -3);

	return 1;
}
