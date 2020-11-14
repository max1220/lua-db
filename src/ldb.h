#ifndef LUA_LDB_H
#define LUA_LDB_H

#include <stdint.h>

#define LDB_VERSION "3.0"
#define LDB_UDATA_NAME "drawbuffer"

// check if a Lua stack index contains a valid drawbuffer, return to lua with an error if not.
#define LUA_LDB_CHECK_DB(L, I, D) D=(drawbuffer_t *)luaL_checkudata(L, I, LDB_UDATA_NAME); if ((D==NULL) || (!D->data)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a drawbuffer", I); return 2; }

// "unpack" the internal pixel value to seperate r,g,b,a uint8_t variables.
#define UNPACK_RGB(P, R, G, B) r = unpack_pixel_r(P); g = unpack_pixel_g(P); b = unpack_pixel_b(P);
#define UNPACK_RGBA(P, R, G, B, A) r = unpack_pixel_r(P); g = unpack_pixel_g(P); b = unpack_pixel_b(P); a = unpack_pixel_a(P);


// supported pixel formats.
// append new formats to bottom of same BPP group.
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

// this struct holds all info for accessing a drawbuffer. Also used as the backing for the Lua userdata.
typedef struct {
    int w, h;
    void* data;
	PIX_FMT pxfmt;
} drawbuffer_t;



// below are inline utillity functions that are usefull in all lua-db modules

// get the bits per pixel for the specified pixel format
static inline size_t get_bpp(PIX_FMT fmt) {
	switch (fmt) {
		case LDB_PXFMT_1BPP_R:
			return 1;
		case LDB_PXFMT_8BPP_R:
		case LDB_PXFMT_8BPP_RGB332:
			return 8;
		case LDB_PXFMT_16BPP_RGB565:
		case LDB_PXFMT_16BPP_BGR565:
			return 16;
		case LDB_PXFMT_24BPP_RGB:
		case LDB_PXFMT_24BPP_BGR:
			return 24;
		case LDB_PXFMT_32BPP_RGBA:
		case LDB_PXFMT_32BPP_ARGB:
		case LDB_PXFMT_32BPP_ABGR:
		case LDB_PXFMT_32BPP_BGRA:
			return 32;
		default:
			return 0;
	}
}

// get the size of the data region for the specified pixel format and dimensions
static inline size_t get_data_size(PIX_FMT fmt, int w, int h) {
	return (w*h*get_bpp(fmt))/8;
}



// "pack" a set of r,g,b,a values to internal uint32_t pixel format
static inline uint32_t pack_pixel_rgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	return r<<24 | g<<16 | b << 8 | a;
}
static inline uint32_t pack_pixel_rgb(uint8_t r, uint8_t g, uint8_t b) {
	return r<<24 | g<<16 | b << 8;
}

// "unpack" an internal uint32_t pixel value to an color value
static inline uint8_t unpack_pixel_r(uint32_t p) {
	return p>>24 & 0xff;
}
static inline uint8_t unpack_pixel_g(uint32_t p) {
	return p>>24 & 0xff;
}
static inline uint8_t unpack_pixel_b(uint32_t p) {
	return p>>24 & 0xff;
}
static inline uint8_t unpack_pixel_a(uint32_t p) {
	return p>>24 & 0xff;
}



// internal functions to set a pixel in memory
static inline void set_px_1bpp(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t j = data[(y*w+x)/8];
	uint8_t i = 1<<(x%8);
	if (p) {
		j = j | i;
	} else {
		j = j & (~i);
	}
	data[(y*w+x)/8] = j;
}
static inline void set_px_8bpp(uint8_t* data, int w, int x, int y, uint32_t p) {
	data[y*w+x] = p&0xff;
}
static inline void set_px_8bpp_rgb332(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b;
	UNPACK_RGB(p, r,g,b)
	uint8_t v = (r&0xe0) | ((g&0xe0)>>3) | ((b&0xc0)>>6);
	data[y*w+x] = v;
}
static inline void set_px_16bpp_rgb565(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b;
	UNPACK_RGB(p, r,g,b)
	uint8_t v1 = (r&0xF8) | ((g&0xE0)>>5);
	uint8_t v2 = ((g&0x1C)<<3) | ((b&0xF8)>>2);
	data[y*w+x] = v1;
	data[y*w+x+1] = v2;
}
static inline void set_px_16bpp_bgr565(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b;
	UNPACK_RGB(p, r,g,b)
	uint8_t v1 = (b&0xF8) | ((g&0xE0)>>5);
	uint8_t v2 = ((g&0x1C)<<3) | ((r&0xF8)>>2);
	data[y*w+x] = v1;
	data[y*w+x+1] = v2;
}
static inline void set_px_24bpp_rgb(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b;
	UNPACK_RGB(p, r,g,b)
	data[(y*w+x)*3] = r;
	data[(y*w+x)*3+1] = g;
	data[(y*w+x)*3+2] = b;
}
static inline void set_px_24bpp_bgr(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b;
	UNPACK_RGB(p, r,g,b)
	data[(y*w+x)*3] = b;
	data[(y*w+x)*3+1] = g;
	data[(y*w+x)*3+2] = r;
}
static inline void set_px_32bpp_rgba(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b,a;
	UNPACK_RGBA(p, r,g,b,a)
	data[(y*w+x)*4] = r;
	data[(y*w+x)*4+1] = g;
	data[(y*w+x)*4+2] = b;
	data[(y*w+x)*4+3] = a;
}
static inline void set_px_32bpp_argb(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b,a;
	UNPACK_RGBA(p, r,g,b,a)
	data[(y*w+x)*4] = a;
	data[(y*w+x)*4+1] = r;
	data[(y*w+x)*4+2] = g;
	data[(y*w+x)*4+3] = b;
}
static inline void set_px_32bpp_abgr(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b,a;
	UNPACK_RGBA(p, r,g,b,a)
	data[(y*w+x)*4] = a;
	data[(y*w+x)*4+1] = b;
	data[(y*w+x)*4+2] = g;
	data[(y*w+x)*4+3] = r;
}
static inline void set_px_32bpp_bgra(uint8_t* data, int w, int x, int y, uint32_t p) {
	uint8_t r,g,b,a;
	UNPACK_RGBA(p, r,g,b,a)
	data[(y*w+x)*4] = b;
	data[(y*w+x)*4+1] = g;
	data[(y*w+x)*4+2] = r;
	data[(y*w+x)*4+3] = a;
}
static inline void set_px(uint8_t* data, int w, int x, int y, uint32_t p, PIX_FMT fmt) {
	switch (fmt) {
		case LDB_PXFMT_1BPP_R:
			set_px_1bpp(data, w, x, y, p); break;
		case LDB_PXFMT_8BPP_R:
			set_px_8bpp(data, w, x, y, p); break;
		case LDB_PXFMT_8BPP_RGB332:
			set_px_8bpp_rgb332(data, w, x, y, p); break;
		case LDB_PXFMT_16BPP_RGB565:
			set_px_16bpp_rgb565(data, w, x, y, p); break;
		case LDB_PXFMT_16BPP_BGR565:
			set_px_16bpp_bgr565(data, w, x, y, p); break;
		case LDB_PXFMT_24BPP_RGB:
			set_px_24bpp_rgb(data, w, x, y, p); break;
		case LDB_PXFMT_24BPP_BGR:
			set_px_24bpp_rgb(data, w, x, y, p); break;
		case LDB_PXFMT_32BPP_RGBA:
			set_px_32bpp_rgba(data, w, x, y, p); break;
		case LDB_PXFMT_32BPP_ARGB:
			set_px_32bpp_argb(data, w, x, y, p); break;
		case LDB_PXFMT_32BPP_ABGR:
			set_px_32bpp_abgr(data, w, x, y, p); break;
		case LDB_PXFMT_32BPP_BGRA:
			set_px_32bpp_bgra(data, w, x, y, p); break;
		default:
			break;
	}
}
static inline void db_set_px(drawbuffer_t* db, int x, int y, uint32_t p) {
	if (x<0 || y<0 || x>=db->w || y>=db->h) {
		return;
	}
	set_px(db->data, db->w, x, y, p, db->pxfmt);
}
static inline void db_set_px_rgba(drawbuffer_t* db, int x, int y, uint8_t r,uint8_t g,uint8_t b,uint8_t a) {
	uint32_t p = pack_pixel_rgba(r,g,b,a);
	db_set_px(db, x, y, p);
}

// internal functions to get a pixel from memory
static inline uint32_t get_px_1bpp(uint8_t* data, int w, int x, int y) {
	uint8_t v = data[(y*w+x)/8];
	if (v&(1<<(x&7))) {
		return pack_pixel_rgb(0xff, 0xff, 0xff);
	}
	return pack_pixel_rgb(0,0,0);
}
static inline uint32_t get_px_8bpp(uint8_t* data, int w, int x, int y) {
	uint8_t v = data[y*w+x];
	return pack_pixel_rgb(v,v,v);
}
static inline uint32_t get_px_8bpp_rgb332(uint8_t* data, int w, int x, int y) {
	uint8_t v = data[y*w+x];
	return pack_pixel_rgb(v&0xe0, (v&0x1c)<<3, (v&0x03)<<6);
}
static inline uint32_t get_px_16bpp_rgb565(uint8_t* data, int w, int x, int y) {
	uint8_t v1 = data[2*(y*w+x)];
	uint8_t v2 = data[2*(y*w+x)+1];
	return pack_pixel_rgb(v1&0xF8, ((v1&0x07)<<5) | ((v2&0xE0)>>3), (v2&0x1f)<<3);
}
static inline uint32_t get_px_16bpp_bgr565(uint8_t* data, int w, int x, int y) {
	uint8_t v1 = data[2*(y*w+x)];
	uint8_t v2 = data[2*(y*w+x)+1];
	return pack_pixel_rgb((v2&0x1f)<<3, ((v1&0x07)<<5) | ((v2&0xE0)>>3), v1&0xF8);
}
static inline uint32_t get_px_24bpp_rgb(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgb(data[2*(y*w+x)], data[2*(y*w+x)+1], data[2*(y*w+x)+2]);
}
static inline uint32_t get_px_24bpp_bgr(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgb(data[2*(y*w+x)+2], data[2*(y*w+x)+1], data[2*(y*w+x)]);
}
static inline uint32_t get_px_32bpp_rgba(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgba(data[2*(y*w+x)], data[2*(y*w+x)+1], data[2*(y*w+x)+2], data[2*(y*w+x)+3]);
}
static inline uint32_t get_px_32bpp_argb(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgba(data[2*(y*w+x)+1], data[2*(y*w+x)+2], data[2*(y*w+x)+3], data[2*(y*w+x)]);
}
static inline uint32_t get_px_32bpp_abgr(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgba(data[2*(y*w+x)+3], data[2*(y*w+x)+2], data[2*(y*w+x)+1], data[2*(y*w+x)]);
}
static inline uint32_t get_px_32bpp_bgra(uint8_t* data, int w, int x, int y) {
	return pack_pixel_rgba(data[2*(y*w+x)+2], data[2*(y*w+x)+1], data[2*(y*w+x)], data[2*(y*w+x)+3]);
}
static inline uint32_t get_px(uint8_t* data, int w, int x, int y, PIX_FMT fmt) {
	switch (fmt) {
		case LDB_PXFMT_1BPP_R:
			return get_px_1bpp(data, w, x, y);
		case LDB_PXFMT_8BPP_R:
			return get_px_8bpp(data, w, x, y);
		case LDB_PXFMT_8BPP_RGB332:
			return get_px_8bpp_rgb332(data, w, x, y);
		case LDB_PXFMT_16BPP_RGB565:
			return get_px_16bpp_rgb565(data, w, x, y);
		case LDB_PXFMT_16BPP_BGR565:
			return get_px_16bpp_bgr565(data, w, x, y);
		case LDB_PXFMT_24BPP_RGB:
			return get_px_24bpp_rgb(data, w, x, y);
		case LDB_PXFMT_24BPP_BGR:
			return get_px_24bpp_rgb(data, w, x, y);
		case LDB_PXFMT_32BPP_RGBA:
			return get_px_32bpp_rgba(data, w, x, y);
		case LDB_PXFMT_32BPP_ARGB:
			return get_px_32bpp_argb(data, w, x, y);
		case LDB_PXFMT_32BPP_ABGR:
			return get_px_32bpp_abgr(data, w, x, y);
		case LDB_PXFMT_32BPP_BGRA:
			return get_px_32bpp_bgra(data, w, x, y);
		default:
			return 0;
	}
}
static inline uint32_t db_get_px(drawbuffer_t* db, int x, int y) {
	if (x<0 || y<0 || x>=db->w || y>=db->h) {
		return 0;
	}
	return get_px(db->data, db->w, x, y, db->pxfmt);
}


#endif
