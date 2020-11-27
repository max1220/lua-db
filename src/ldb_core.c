#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"



// utillity macros
#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_I_S(N, S) lua_pushinteger(L, N); lua_pushstring(L, S); lua_settable(L, -3);



// get the cannoncial string representing the pixel format
static const char* pixel_format_to_str(PIX_FMT fmt) {
	switch(fmt) {
		case LDB_PXFMT_1BPP: return "bit";
		case LDB_PXFMT_8BPP: return "byte";
		case LDB_PXFMT_8BPP_RGB332: return "rgb332";
		case LDB_PXFMT_16BPP_RGB565: return "rgb565";
		case LDB_PXFMT_16BPP_BGR565: return "bgr565";
		case LDB_PXFMT_24BPP_RGB: return "rgb888";
		case LDB_PXFMT_24BPP_BGR: return "bgr888";
		case LDB_PXFMT_32BPP_RGBA: return "rgba8888";
		case LDB_PXFMT_32BPP_ARGB: return "argb8888";
		case LDB_PXFMT_32BPP_ABGR: return "abgr8888";
		case LDB_PXFMT_32BPP_BGRA: return "bgra8888";
		default: return "Unknown";
	}
}

// get the pixel format number from a pixel format string
static PIX_FMT str_to_pixel_format(const char* str) {
	if (strcmp(str, "bit")==0) { return LDB_PXFMT_1BPP; }
	else if (strcmp(str, "byte")==0) { return LDB_PXFMT_8BPP; }
	else if (strcmp(str, "rgb332")==0) { return LDB_PXFMT_8BPP_RGB332; }
	else if (strcmp(str, "rgb565")==0) { return LDB_PXFMT_16BPP_RGB565; }
	else if (strcmp(str, "bgr565")==0) { return LDB_PXFMT_16BPP_BGR565; }
	else if (strcmp(str, "rgb888")==0) { return LDB_PXFMT_24BPP_RGB; }
	else if (strcmp(str, "bgr888")==0) { return LDB_PXFMT_24BPP_BGR; }
	else if (strcmp(str, "rgba8888")==0) { return LDB_PXFMT_32BPP_RGBA; }
	else if (strcmp(str, "argb8888")==0) { return LDB_PXFMT_32BPP_ARGB; }
	else if (strcmp(str, "abgr8888")==0) { return LDB_PXFMT_32BPP_ABGR; }
	else if (strcmp(str, "bgra8888")==0) { return LDB_PXFMT_32BPP_BGRA; }
	return LDB_PXFMT_MAX;
}

// return a string with info about the drawbuffer to Lua
static int lua_drawbuffer_tostring(lua_State *L) {
	// can't use LUA_LDB_CHECK_DB(L, 1, db) because we want to return a string even if closed
	drawbuffer_t *db = luaL_checkudata(L, 1, LDB_UDATA_NAME);
	if (db==NULL) {
		lua_pushstring(L, "Unknown");
		return 1;
	}

	if (!db->data) {
		lua_pushstring(L, "Closed Drawbuffer");
		return 1;
	}

	switch (db->pxfmt) {
		case LDB_PXFMT_1BPP:
			lua_pushfstring(L, "1bpp Drawbuffer: %dx%d", db->w, db->h);
			return 1;
		case LDB_PXFMT_8BPP:
			lua_pushfstring(L, "8bpp Drawbuffer: %dx%d", db->w, db->h);
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
			lua_pushfstring(L, "Unknown Drawbuffer: %dx%d", db->w, db->h);
			return 1;
	}
}

// return length of pixel data in bytes to Lua
static int lua_drawbuffer_bytelen(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, get_data_size(db->pxfmt, db->w, db->h));
	return 1;
}

// return the width of a drawbuffer to Lua
static int lua_drawbuffer_width(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, db->w);
	return 1;
}

// return the height of a drawbuffer to Lua
static int lua_drawbuffer_height(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushinteger(L, db->h);
	return 1;
}

// return the pixel format as a string
static int lua_drawbuffer_pixel_format(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushstring(L, pixel_format_to_str(db->pxfmt));
	return 1;
}

// close an instance of a drawbuffer, calling free() on the allocated
// memory, if needed. Automatically called by the Lua GC
static int lua_drawbuffer_close(lua_State *L) {
	drawbuffer_t *db;
 	LUA_LDB_CHECK_DB(L, 1, db)

	if (db->close_func) {
		db->close_func(db);
	} else if (db->data) {
		free(db->data);
		db->data = NULL;
	}

	lua_pushboolean(L, 1);
	return 1;
}

// return r,g,b,a value for the drawbuffer at x,y
static int lua_drawbuffer_get_px(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)
	if (!lua_isnumber(L, 2) || !lua_isnumber(L, 3)) {
		return 0;
	}
	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);

	if (x<0 || y<0 || x>=db->w || y>=db->h) {
		return 0;
	}

	uint32_t p = get_px(db->data, db->w, x,y, db->pxfmt);

	lua_pushinteger(L, unpack_pixel_r(p));
	lua_pushinteger(L, unpack_pixel_g(p));
	lua_pushinteger(L, unpack_pixel_b(p));
	lua_pushinteger(L, unpack_pixel_a(p));
	return 4;
}

// set r,g,b,a value for the drawbuffer at x,y
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
	if ((r>255) || (g>255) || (b>255) || (a>255) || (r<0) || (g<0) || (b<0) || (a<0) || (x<0) || (y<0) || (x>=db->w) || (y>=db->h)) {
		return 0;
	}

	uint32_t p = pack_pixel_rgba(r,g,b,a);
	set_px(db->data, db->w, x,y, p, db->pxfmt);

	lua_pushboolean(L, 1);
	return 1;
}

// clear the drawbuffer in a uniform color
static int lua_drawbuffer_clear(lua_State *L) {
	drawbuffer_t *db = (drawbuffer_t *)lua_touserdata(L, 1);
	LUA_LDB_CHECK_DB(L, 1, db)
	int r = lua_tointeger(L, 2);
	int g = lua_tointeger(L, 3);
	int b = lua_tointeger(L, 4);
	int a = lua_tointeger(L, 5);
	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		return 0;
	}

	uint32_t p = pack_pixel_rgba(r,g,b,a);

	if ( (r==g) && (g==b) && (b==a) && (db->pxfmt>=LDB_PXFMT_24BPP_RGB) ) {
		// fastpath
		memset(db->data, r, get_data_size(db->pxfmt, db->w, db->h));
	} else {
		for (int y = 0; y < db->h; y++) {
			for (int x = 0; x < db->w; x++) {
				set_px(db->data, db->w, x,y, p, db->pxfmt);
			}
		}
	}

	lua_pushboolean(L, 1);
	return 1;
}

// return the internal drabuffer pixel data as a string
static int lua_drawbuffer_dump_data(lua_State *L) {
	drawbuffer_t *db = (drawbuffer_t *)lua_touserdata(L, 1);
	LUA_LDB_CHECK_DB(L, 1, db)

	lua_pushlstring(L, (char*)db->data, get_data_size(db->pxfmt, db->w, db->h));
	return 1;
}

// load drabuffer pixel data from a string
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

	lua_pushboolean(L, 1);
	return 1;
}


void lua_set_ldb_meta(lua_State *L, int i) {
	// push/create metatable for userdata.
	// The same metatable is used for every drawbuffer instance.
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
	lua_setmetatable(L, i);
}


// create a new drawbuffer userdata object
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
	if (lua_isstring(L, 3)) {
		const char* fmt_str = lua_tostring(L, 3);
		fmt = str_to_pixel_format(fmt_str);
	} else if (lua_isnumber(L, 3)) {
		fmt = lua_tonumber(L, 3);
	}
	if ((fmt >= LDB_PXFMT_MAX) || (fmt<0)) {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown format!");
		return 2;
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
	db->close_func = NULL;
	db->close_data = NULL;

	// Apply drawbuffer metatable to userdata object
	lua_set_ldb_meta(L, -2);

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

	lua_settable(L, -3);

	return 1;
}
