#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>


#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"


#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_I_S(N, S) lua_pushinteger(L, N); lua_pushstring(L, S); lua_settable(L, -3);





static inline uint32_t alphablend(uint32_t sp, uint32_t tp) {
	if ((tp&0xff)==0) {
		return sp;
	} else if ((tp&0xff)==0xff) {
		return tp;
	}

	// blend alpha, e.g. for red: sp.r * (1-tp.a) + tp.r*tp.a
	uint32_t ret = tp & 0xff;
	ret |= (uint32_t)((float)((sp&0xff000000)>>24) * (1-((float)(tp&0xff)/255.0)) + (float)((tp&0xff000000)>>24) * ((float)(tp&0xff)/255.0))<<24;
	ret |= (uint32_t)((float)((sp&0x00ff0000)>>16) * (1-((float)(tp&0xff)/255.0)) + (float)((tp&0x00ff0000)>>16) * ((float)(tp&0xff)/255.0))<<16;
	ret |= (uint32_t)((float)((sp&0x0000ff00)>>8)  * (1-((float)(tp&0xff)/255.0)) + (float)((tp&0x0000ff00)>>8) * ((float)(tp&0xff)/255.0))<<8;

	return ret;
}

// TODO: include this in the header?
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

static inline void draw_origin_to_target(drawbuffer_t* origin_db, drawbuffer_t* target_db, int target_x, int target_y, int origin_x, int origin_y, int w, int h) {
	int cx,cy;
	uint32_t p;
	// copy from origin (at origin offset) to target(at target offset)

	// TODO: test fastpath for same pixel format and offsets == 0 using memcpy
	//if ((origin_db->w==target_db->w) && (origin_db->w==w) && (origin_db->h==target_db->h) && (origin_db->h==h) && (target_x==0) && (target_y==0) && (origin_x==0) && (origin_y==0) && (origin_db->pxfmt == target_db->pxfmt)) {
	//	memcpy(target_db->data, origin_db->data, get_data_size(origin_db->pxfmt, origin_db->w, origin_db->h));
	//}
	for (cy = 0; cy < h; cy++) {
		for (cx = 0; cx < w; cx++) {
			p = ldb_get_px(origin_db, cx+origin_x,cy+origin_y);
			ldb_set_px(target_db, cx+target_x, cy+target_y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		}
	}
}

static inline void draw_origin_to_target_scaled(drawbuffer_t* origin_db, drawbuffer_t* target_db, int target_x, int target_y, int origin_x, int origin_y, int w, int h, int scale_x, int scale_y) {
	int cx,cy;
	int sx,sy;
	uint32_t p;

	// copy from origin (at origin offset) to target(at target offset, scaled so that every pixel now is scale pixels wide in the target)
	for (cy = 0; cy < h; cy++) {
		for (cx = 0; cx < w; cx++) {
			p = ldb_get_px(origin_db, cx+origin_x, cy+origin_y);
			for (sy = 0; sy < scale_y; sy++) {
				for (sx = 0; sx < scale_x; sx++) {
					ldb_set_px(target_db, cx*scale_x+sx+target_x, cy*scale_y+sy+target_y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
				}
			}
		}
	}
}

static inline void draw_origin_to_target_ignorealpha(drawbuffer_t* origin_db, drawbuffer_t* target_db, int target_x, int target_y, int origin_x, int origin_y, int w, int h) {
	int cx,cy;
	uint32_t p;

	// copy from origin (at origin offset) to target(at target offset), don't copy pixels from origin if a=0
	for (cy = 0; cy < h; cy++) {
		for (cx = 0; cx < w; cx++) {
			p = ldb_get_px(origin_db, cx+origin_x,cy+origin_y);
			if (p&0xff) {
				ldb_set_px(target_db, cx+target_x, cy+target_y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
			}
		}
	}
}

static inline void draw_origin_to_target_ignorealpha_scaled(drawbuffer_t* origin_db, drawbuffer_t* target_db, int target_x, int target_y, int origin_x, int origin_y, int w, int h, int scale_x, int scale_y) {
	int cx,cy,sx,sy;
	uint32_t p;

	// copy from origin (at origin offset) to target(at target offset, scaled), don't copy pixels from origin if a=0
	for (cy = 0; cy < h; cy++) {
		for (cx = 0; cx < w; cx++) {
			p = ldb_get_px(origin_db, cx+origin_x,cy+origin_y);
			if (p&0xff) {
				for (sy = 0; sy < scale_y; sy++) {
					for (sx = 0; sx < scale_x; sx++) {
						ldb_set_px(target_db, cx*scale_x+sx+target_x, cy*scale_y+sy+target_y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
					}
				}
			}
		}
	}
}

static inline void draw_origin_to_target_alphablend(drawbuffer_t* origin_db, drawbuffer_t* target_db, int target_x, int target_y, int origin_x, int origin_y, int w, int h) {
	int cx,cy;
	uint32_t sp, tp, p;

	// copy from origin (at origin offset) to target(at target offset), alphablend pixels(allows for semi-transparency)
	for (cy=0; cy < h; cy++) {
		for (cx=0; cx < w; cx++) {
			sp = ldb_get_px(origin_db, cx+origin_x,cy+origin_y);
			tp = ldb_get_px(target_db, cx+target_x, cy+target_y);
			p = alphablend(tp, sp);
			ldb_set_px(target_db, cx+target_x, cy+target_y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		}
	}
}



static inline void floyd_steinberg_increment_pixel(drawbuffer_t* db, int x, int y, uint8_t w, uint8_t r_err, uint8_t g_err, uint8_t b_err) {
	uint32_t tp = ldb_get_px(db, x, y);
	uint32_t t_r = (tp&0xff000000)>>24;
	uint32_t t_g = (tp&0x00ff0000)>>16;
	uint32_t t_b = (tp&0x0000ff00)>>8;

	t_r = t_r + ((r_err*w)>>4);
	t_g = t_g + ((g_err*w)>>4);
	t_b = t_b + ((b_err*w)>>4);

	ldb_set_px(db, x, y, t_r>255?255:t_r,t_g>255?255:t_g,t_b>255?255:t_b, tp&0xff);
}

static inline void floyd_steinberg_16bpp_rgb565(drawbuffer_t* db) {
	int cx,cy;
	uint32_t tp;
	uint8_t r,g,b;
	uint8_t r_err, g_err, b_err;

	for (cy=0; cy < db->h; cy++) {
		for (cx=0; cx < db->w; cx++) {
			tp = ldb_get_px(db, cx,cy);
			r = (tp&0xff000000)>>24;
			g = (tp&0x00ff0000)>>16;
			b = (tp&0x0000ff00)>>8;
			ldb_set_px(db, cx,cy, r&0xf8,g&0xfc,b&0xf8, tp&0xff);
			r_err = r&0x07;
			g_err = g&0x03;
			b_err = b&0x07;
			floyd_steinberg_increment_pixel(db, cx+1, cy, 7, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx-1, cy+1, 3, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx, cy+1, 5, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx+1, cy+1, 1, r_err, g_err, b_err);
		}
	}
}

static inline void floyd_steinberg_8bpp_rgb332(drawbuffer_t* db) {
	int cx,cy;
	uint32_t tp;
	uint8_t r,g,b;
	uint8_t r_err, g_err, b_err;

	for (cy=0; cy < db->h; cy++) {
		for (cx=0; cx < db->w; cx++) {
			tp = ldb_get_px(db, cx,cy);
			r = (tp&0xff000000)>>24;
			g = (tp&0x00ff0000)>>16;
			b = (tp&0x0000ff00)>>8;
			ldb_set_px(db, cx,cy, r&0xe0,g&0xe0,b&0xc0, tp&0xff);
			r_err = r&0x1f;
			g_err = g&0x1f;
			b_err = b&0x3f;
			floyd_steinberg_increment_pixel(db, cx+1, cy, 7, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx-1, cy+1, 3, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx, cy+1, 5, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx+1, cy+1, 1, r_err, g_err, b_err);
		}
	}
}

static inline void floyd_steinberg_1bpp_r(drawbuffer_t* db) {
	int cx,cy;
	uint32_t tp;
	uint8_t r,g,b;
	uint8_t r_err, g_err, b_err;

	for (cy=0; cy < db->h; cy++) {
		for (cx=0; cx < db->w; cx++) {
			tp = ldb_get_px(db, cx,cy);
			r = (tp&0xff000000)>>24;
			g = (tp&0x00ff0000)>>16;
			b = (tp&0x0000ff00)>>8;
			ldb_set_px(db, cx,cy, r&0x80,g&0x80,b&0x80, tp&0xff);
			r_err = r&0x7f;
			g_err = g&0x7f;
			b_err = b&0x7f;
			floyd_steinberg_increment_pixel(db, cx+1, cy, 7, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx-1, cy+1, 3, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx, cy+1, 5, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db, cx+1, cy+1, 1, r_err, g_err, b_err);
		}
	}
}



static inline void line(drawbuffer_t* db, int x0, int y0, int x1, int y1, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int dx,dy;
	int sx,sy;
	int err, e2;

	dx = abs(x1-x0);
	dy = abs(y1-y0);
	sx = (x0<x1 ? 1 : -1);
	sy = (y0<y1 ? 1 : -1);
	err = (dx>dy ? dx : -dy)/2;

	while(1) {
		ldb_set_px(db, x0,y0,r,g,b,a);
		if (x0==x1 && y0==y1) {
			break;
		}
		e2 = err;
		if (e2 > -dx) {
			err -= dy;
			x0 += sx;
		}
		if (e2 < dy) {
			err += dx;
			y0 += sy;
		}
	}
}

static inline void line_alphablend(drawbuffer_t* db, int x0, int y0, int x1, int y1, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int dx,dy;
	int sx,sy;
	int err, e2;
	uint32_t sp, p;
	uint32_t tp = ((uint32_t)r)<<24 | ((uint32_t)g)<<16 | ((uint32_t)b)<<8 | a;

	dx = abs(x1-x0);
	dy = abs(y1-y0);
	sx = (x0<x1 ? 1 : -1);
	sy = (y0<y1 ? 1 : -1);
	err = (dx>dy ? dx : -dy)/2;

	while(1) {
		sp = ldb_get_px(db, x0, y0);
		p = alphablend(sp, tp);
		ldb_set_px(db, x0, y0, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		if (x0==x1 && y0==y1) {
			break;
		}
		e2 = err;
		if (e2 > -dx) {
			err -= dy;
			x0 += sx;
		}
		if (e2 < dy) {
			err += dx;
			y0 += sy;
		}
	}
}

static inline float capsuleSDF(float px, float py, float ax, float ay, float bx, float by, float r) {
    float pax = px - ax, pay = py - ay, bax = bx - ax, bay = by - ay;
    float h = fmaxf(fminf((pax * bax + pay * bay) / (bax * bax + bay * bay), 1.0f), 0.0f);
    float dx = pax - bax * h, dy = pay - bay * h;
    return sqrtf(dx * dx + dy * dy) - r;
}

static inline void line_anti_aliased(drawbuffer_t* db, int x0, int y0, int x1, int y1, uint8_t r, uint8_t g, uint8_t b, uint8_t a, float radius) {
	float alpha;
	uint32_t sp, p;
	int cx, cy;
	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8);

    int x_min = (int)floorf(fminf((float)x0, (float)x1) - radius);
    int x_max = (int) ceilf(fmaxf((float)x0, (float)x1) + radius);
    int y_min = (int)floorf(fminf((float)y0, (float)y1) - radius);
    int y_max = (int) ceilf(fmaxf((float)y0, (float)y1) + radius);

    for (cy = y_min; cy <= y_max; cy++) {
		for (cx = x_min; cx <= x_max; cx++) {
			alpha = fmaxf(fminf(0.5f - capsuleSDF(cx, cy, (float)x0, (float)y0, (float)x1, (float)y1, radius), 1.0f), 0.0f)*(float)a;
			if (alpha>0) {
				sp = ldb_get_px(db, cx, cy);
				p = alphablend(sp, tp | ((uint32_t)alpha));
				ldb_set_px(db, cx, cy, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
			}
		}
	}
}



static inline void rectangle_fill(drawbuffer_t* db, int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int cx, cy;
	for (cy = y; cy < y+h; cy++) {
		for (cx = x; cx < x+w; cx++) {
			ldb_set_px(db, cx, cy, r,g,b,a);
		}
	}
}

static inline void rectangle_outline(drawbuffer_t* db, int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int cx, cy;
	for (cx = x; cx < x+w; cx++) {
		ldb_set_px(db, cx, y, r,g,b,a);
		ldb_set_px(db, cx, y+(h-1), r,g,b,a);
	}
	for (cy = y+1; cy < y+h-1; cy++) {
		ldb_set_px(db, x, cy, r,g,b,a);
		ldb_set_px(db, x+(w-1), cy, r,g,b,a);
	}
}

static inline void rectangle_fill_alphablend(drawbuffer_t* db, int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int cx, cy;
	uint32_t sp, p;
	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8) | (uint32_t)a;

	for (cy = y; cy < y+h; cy++) {
		for (cx = x; cx < x+w; cx++) {
			sp = ldb_get_px(db, cx, cy);
			p = alphablend(sp, tp);
			ldb_set_px(db, cx, cy, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		}
	}
}

static inline void rectangle_outline_alphablend(drawbuffer_t* db, int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int cx, cy;
	uint32_t p;
	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8) | (uint32_t)a;

	for (cx = x; cx < x+w; cx++) {
		p = alphablend(ldb_get_px(db, cx, y), tp);
		ldb_set_px(db, cx, y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		p = alphablend(ldb_get_px(db, cx, y+(h-1)), tp);
		ldb_set_px(db, cx, y+(h-1), (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
	}
	for (cy = y+1; cy < y+h-1; cy++) {
		p = alphablend(ldb_get_px(db, x, cy), tp);
		ldb_set_px(db, x, cy, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
		p = alphablend(ldb_get_px(db, x+(w-1), cy), tp);
		ldb_set_px(db, x+(w-1), cy, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
	}
}



static inline void set_vline(drawbuffer_t* db, int y, float x0, float x1, uint32_t tp) {
	int cx;

	for (cx= (x0 < x1 ? x0 : x1); cx<=(x0 > x1 ? x0 : x1); cx++) {
		ldb_set_px(db, cx, y, (tp&0xFF000000)>>24, (tp&0x00FF0000)>>16, (tp&0x0000FF00)>>8, tp&0xFF);
	}
}

static inline void set_vline_alphablend(drawbuffer_t* db, int y, float x0, float x1, uint32_t tp) {
	int cx;
	uint32_t p;

	for (cx= (x0 < x1 ? x0 : x1); cx<=(x0 > x1 ? x0 : x1); cx++) {
		p = alphablend(ldb_get_px(db, cx, y), tp);
		ldb_set_px(db, cx, y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
	}
}

static inline void triangle_top(drawbuffer_t* db, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp) {
	// fill the flat(at the top) triangle. vertice y must be ascending.
	float slope1 = (x2-x0)/(y2-y0);
	float slope2 = (x2-x1)/(y2-y1);
	float cx1 = x2;
	float cx2 = x2;

	for (int cy=y2; cy>=y0; cy--) {
		set_vline(db, cy, cx1, cx2, tp);
		cx1 -= slope1;
		cx2 -= slope2;
	}
}

static inline void triangle_bottom(drawbuffer_t* db, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp) {
	// fill the flat(at the bottom) triangle. vertice y must be ascending.
	float slope1 = (x1-x0) / (y1-y0);
	float slope2 = (x2-x0) / (y2-y0);
	float cx1 = x0;
	float cx2 = x0;

	for (int cy=y0; cy<=y1; cy++) {
		set_vline(db, cy, cx1, cx2, tp);
		cx1 += slope1;
		cx2 += slope2;
	}
}

static inline void triangle_top_alphablend(drawbuffer_t* db, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp) {
	// fill the flat(at the top) triangle. vertice y must be ascending.
	float slope1 = (x2-x0)/(y2-y0);
	float slope2 = (x2-x1)/(y2-y1);
	float cx1 = x2;
	float cx2 = x2;

	for (int cy=y2; cy>=y0; cy--) {
		set_vline_alphablend(db, cy, cx1, cx2, tp);
		cx1 -= slope1;
		cx2 -= slope2;
	}
}

static inline void triangle_bottom_alphablend(drawbuffer_t* db, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp) {
	// fill the flat(at the bottom) triangle. vertice y must be ascending.
	float slope1 = (x1-x0) / (y1-y0);
	float slope2 = (x2-x0) / (y2-y0);
	float cx1 = x0;
	float cx2 = x0;

	for (int cy=y0; cy<=y1; cy++) {
		set_vline_alphablend(db, cy, cx1, cx2, tp);
		cx1 += slope1;
		cx2 += slope2;
	}
}

static inline void triangle(drawbuffer_t* db, int x0, int y0, int x1, int y1, int x2, int y2, uint32_t tp, int alphablend) {
	int tmp_x, tmp_y;
	int split;

	if (y0 > y2) {
		tmp_x = x0; x0 = x2; x2 = tmp_x;
		tmp_y = y0; y0 = y2; y2 = tmp_y;
	}
	if (y0 > y1) {
		tmp_x = x0; x0 = x1; x1 = tmp_x;
		tmp_y = y0; y0 = y1; y1 = tmp_y;
	}
	if (y1 > y2) {
		tmp_x = x1; x1 = x2; x2 = tmp_x;
		tmp_y = y1; y1 = y2; y2 = tmp_y;
	}

	// check if triangle is visible
	if (((y0 < 0) && (y2 < 0)) || ((y0 >= db->h) && (y2 >= db->h))) {
		return;
	}

	if (alphablend) {
		if (y1==y2) {
			triangle_bottom_alphablend(db, x0,y0, x1,y1, x2,y2, tp);
		} else if (y0==y1) {
			triangle_top_alphablend(db, x0,y0, x1,y1, x2,y2, tp);
		} else {
			split = (int)(x0 + ((float)(y1 - y0) / (float)(y2 - y0)) * (x2 - x0));
			triangle_bottom_alphablend(db, x0,y0, x1,y1, split,y1, tp);
			triangle_top_alphablend(db, x1,y1, split,y1, x2,y2, tp);
		}
	} else {
		if (y1==y2) {
			triangle_bottom(db, x0,y0, x1,y1, x2,y2, tp);
		} else if (y0==y1) {
			triangle_top(db, x0,y0, x1,y1, x2,y2, tp);
		} else {
			split = (int)(x0 + ((float)(y1 - y0) / (float)(y2 - y0)) * (x2 - x0));
			triangle_bottom(db, x0,y0, x1,y1, split,y1, tp);
			triangle_top(db, x1,y1, split,y1, x2,y2, tp);
		}
	}
}



static inline float circleSDF(float px, float py, float cx, float cy, float r) {
	float dx = px-cx;
	float dy = py-cy;
    return sqrtf(dx*dx + dy*dy) - r;
}

static inline void circle_fill_aliased(drawbuffer_t* db, float center_x, float center_y, float radius, uint8_t r, uint8_t g, uint8_t b, uint8_t a, int outline) {
	float alpha, d;
	uint32_t sp, p;
	int cx, cy;
	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8);

	int x_min = (int)floorf(center_x-radius);
	int x_max = (int) ceilf(center_x+radius);
	int y_min = (int)floorf(center_y-radius);
	int y_max = (int) ceilf(center_y+radius);

    for (cy = y_min; cy <= y_max; cy++) {
		for (cx = x_min; cx <= x_max; cx++) {
			d = circleSDF(cx, cy, center_x, center_y, radius);
			if (outline && (d<0)) {
				d = -d;
			}
			alpha = fmaxf(fminf(0.5f - d, 1.0f), 0.0f)*(float)a;
			if (alpha>0) {
				sp = ldb_get_px(db, cx, cy);
				p = alphablend(sp, tp | ((uint32_t)alpha));
				ldb_set_px(db, cx, cy, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);
			}
		}
	}
}

static inline void circle_fill(drawbuffer_t* db, int x, int y, int radius, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int r2 = radius * radius;
	int area = r2 << 2;
	int rr = radius << 1;
	int i, tx, ty;
	for (i = 0; i < area; i++) {
    	tx = (i % rr) - radius;
    	ty = (i / rr) - radius;
    	if (tx * tx + ty * ty <= r2) {
        	ldb_set_px(db, x + tx, y + ty, r,g,b,a);
		}
	}
}

static inline void circle_set8(drawbuffer_t* db, int x, int y, int cx, int cy, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	ldb_set_px(db, x+cx, y+cy, r,g,b,a);
    ldb_set_px(db, x-cx, y+cy, r,g,b,a);
    ldb_set_px(db, x+cx, y-cy, r,g,b,a);
    ldb_set_px(db, x-cx, y-cy, r,g,b,a);
    ldb_set_px(db, x+cy, y+cx, r,g,b,a);
    ldb_set_px(db, x-cy, y+cx, r,g,b,a);
    ldb_set_px(db, x+cy, y-cx, r,g,b,a);
    ldb_set_px(db, x-cy, y-cx, r,g,b,a);
}

static inline void circle_outline(drawbuffer_t* db, int x, int y, int radius, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	int cx = 0;
	int cy = radius;
    int d = 3 - 2 * radius;
    circle_set8(db, x, y, cx, cy, r,g,b,a);
    while (cy >= cx) {
        cx++;
        if (d > 0) {
            cy--;
            d = d + 4 * (cx - cy) + 10;
        } else {
			d = d + 4 * cx + 6;
		}
        circle_set8(db, x, y, cx, cy, r,g,b,a);
    }
}



static inline void rgb_to_hsv(float r, float g, float b, float* h, float* s, float* v) {
	float max_v = fmaxf(fmaxf(r, g), b);
	float min_v = fminf(fminf(r, g), b);
	float delta = max_v - min_v;

	if(delta > 0) {
		if(max_v == r) {
			*h = (fmodf(((g - b) / delta), 6))/6;
		} else if(max_v == g) {
			*h = (((b - r) / delta) + 2)/6;
		} else if(max_v == b) {
			*h = (((r - g) / delta) + 4)/6;
		}
		if(max_v > 0) {
			*s = delta / max_v;
		} else {
			*s = 0;
		}
		*v = max_v;
	} else {
		*h = 0;
		*s = 0;
		*v = max_v;
	}
	if(*h < 0) {
		*h = 1 + *h;
	}
}

static inline void hsv_to_rgb(float h, float s, float v, float* r, float* g, float* b) {
	float c = v * s;
	float h_6 = fmodf(h*6, 6);
	float x = c * (1 - fabsf(fmodf(h_6, 2) - 1));
	float m = v - c;
	if(0 <= h_6 && h_6 < 1) {
		*r = c;
		*g = x;
		*b = 0;
	} else if(1 <= h_6 && h_6 < 2) {
		*r = x;
		*g = c;
		*b = 0;
	} else if(2 <= h_6 && h_6 < 3) {
		*r = 0;
		*g = c;
		*b = x;
	} else if(3 <= h_6 && h_6 < 4) {
		*r = 0;
		*g = x;
		*b = c;
	} else if(4 <= h_6 && h_6 < 5) {
		*r = x;
		*g = 0;
		*b = c;
	} else if(5 <= h_6 && h_6 < 6) {
		*r = c;
		*g = 0;
		*b = x;
	} else {
		*r = 0;
		*g = 0;
		*b = 0;
	}
	*r += m;
	*g += m;
	*b += m;
}



static int lua_gfx_origin_to_target(lua_State *L) {
	// draws a drawbuffer to another drawbuffer
	drawbuffer_t *origin_db;
	LUA_LDB_CHECK_DB(L, 1, origin_db)

	drawbuffer_t *target_db;
	LUA_LDB_CHECK_DB(L, 2, target_db)

	int target_x = lua_tointeger(L, 3);
	int target_y = lua_tointeger(L, 4);

	int origin_x = lua_tointeger(L, 5);
	int origin_y = lua_tointeger(L, 6);

	int w = lua_tointeger(L, 7);
	int h = lua_tointeger(L, 8);

	int scale_x = lua_tointeger(L, 9);
	int scale_y = lua_tointeger(L, 10);

	if ((w<=0) || (h<=0)) {
		w = origin_db->w;
		h = origin_db->h;
	}

	if (scale_x<=0) {
		scale_x = 1;
	}
	if (scale_y<=0) {
		scale_y = scale_x;
	}

	const char* arg_str;
	int alpha_mode = 0;
	if (lua_isstring(L, 11)) {
		arg_str = lua_tostring(L, 11);
		if (strcmp(arg_str, "ignorealpha")==0) {
			alpha_mode = 1;
		} else if (strcmp(arg_str, "alphablend")==0) {
			alpha_mode = 2;
		}
	}

	if (alpha_mode == 0) {
		if ((scale_x>1) || (scale_y>1)) {
			draw_origin_to_target_scaled(origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h, scale_x, scale_y);
		} else {
			draw_origin_to_target(origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h);
		}
	} else if (alpha_mode == 1) {
		if ((scale_x>1) || (scale_y>1)) {
			draw_origin_to_target_ignorealpha_scaled(origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h, scale_x, scale_y);
		} else {
			draw_origin_to_target_ignorealpha(origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h);
		}
	} else if (alpha_mode == 2) {
		if ((scale_x>1) || (scale_y>1)) {
			lua_pushnil(L);
			lua_pushstring(L, "Can't use alpha blending mode with scale!");
			return 2;
		} else {
			draw_origin_to_target_alphablend(origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h);
		}
	}

	return 0;
}

static int lua_gfx_floyd_steinberg(lua_State *L) {
	// draws a drawbuffer to another drawbuffer
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int bpp = lua_tonumber(L, 2);
	if (bpp==1) {
		floyd_steinberg_1bpp_r(db);
		return 0;
	} else if (bpp==8) {
		floyd_steinberg_8bpp_rgb332(db);
		return 0;
	} else if (bpp==16) {
		floyd_steinberg_16bpp_rgb565(db);
		return 0;
	} else {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown bpp! Dithering is only supported for 1bpp, 8bpp and 16bpp.");
		return 2;
	}
}

static int lua_gfx_pixel_function(lua_State *L) {
	// call a Lua function for each pixel in the drawbuffer,
	// setting the pixel to the return value of the Lua function.
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int err;
	const char* err_str;
	int r,g,b,a;
	int cx,cy;

	for (cy = 0; cy < db->h; cy++) {
		for (cx = 0; cx < db->w; cx++) {
			uint32_t p = ldb_get_px(db, cx,cy);

			// duplicate function reference
			lua_pushvalue(L, 2);

			// push 6 function arguments(x,y,r,g,b,a)
			lua_pushinteger(L, cx);
			lua_pushinteger(L, cy);
			lua_pushinteger(L, (p&0xFF000000)>>24);
			lua_pushinteger(L, (p&0x00FF0000)>>16);
			lua_pushinteger(L, (p&0x0000FF00)>>8);
			lua_pushinteger(L, p&0xFF);

			// execute( lua: pixel_function(x,y,r,g,b,a) )
			err = lua_pcall(L, 6, 4, 0);
			if (err) {
				err_str = lua_tostring(L, 1);
				lua_pushnil(L);
				if (err_str) {
					lua_pushfstring(L, "Pixel function error: %q", err_str);
					return 2;
				}
				return 1;
			}

			// update p
			a = lua_tointeger(L, -1);
			b = lua_tointeger(L, -2);
			g = lua_tointeger(L, -3);
			r = lua_tointeger(L, -4);

			// check if valid pixel
			if ( (r<0) || (g<0) || (b<0) || (a<0) || (r>255) || (g>255) || (b>255) || (a>255) ) {
				lua_pushnil(L);
				lua_pushstring(L, "Invalid pixel value returned in pixel function!");
			}

			// remove arguments
			lua_pop(L, 4);

			// Write back to drawbuffer
			ldb_set_px(db, cx,cy,r,g,b,a);
		}
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_gfx_line(lua_State *L) {
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int x0 = lua_tointeger(L, 2);
	int y0 = lua_tointeger(L, 3);
	int x1 = lua_tointeger(L, 4);
	int y1 = lua_tointeger(L, 5);

	int r = lua_tointeger(L, 6);
	int g = lua_tointeger(L, 7);
	int b = lua_tointeger(L, 8);
	int a = lua_tointeger(L, 9);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}

	float radius;
	if (lua_isnumber(L, 10)) {
		radius = lua_tonumber(L, 10);
		if (radius <= 0) {
			radius = 1;
		}
		line_anti_aliased(db, x0, y0, x1, y1, r,g,b,a, radius);
		return 0;
	} else if (lua_toboolean(L, 10)) {
		line_alphablend(db, x0, y0, x1, y1, r,g,b,a);
		return 0;
	} else {
		line(db, x0, y0, x1, y1, r,g,b,a);
		return 0;
	}
}

static int lua_gfx_rectangle(lua_State *L) {
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	int w = lua_tointeger(L, 4);
	int h = lua_tointeger(L, 5);

	int r = lua_tointeger(L, 6);
	int g = lua_tointeger(L, 7);
	int b = lua_tointeger(L, 8);
	int a = lua_tointeger(L, 9);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}

	int outline = lua_toboolean(L, 10);
	int alphablend = lua_toboolean(L, 11);

	if (outline) {
		if (alphablend) {
			rectangle_outline_alphablend(db, x,y, w,h, r,g,b,a);
		} else {
			rectangle_outline(db, x,y, w,h, r,g,b,a);
		}
	} else {
		if (alphablend) {
			rectangle_fill_alphablend(db, x,y, w,h, r,g,b,a);
		} else {
			rectangle_fill(db, x,y, w,h, r,g,b,a);
		}
	}

	return 0;
}

static int lua_gfx_triangle(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int x0 = lua_tointeger(L, 2);
	int y0 = lua_tointeger(L, 3);
	int x1 = lua_tointeger(L, 4);
	int y1 = lua_tointeger(L, 5);
	int x2 = lua_tointeger(L, 6);
	int y2 = lua_tointeger(L, 7);

	int r = lua_tointeger(L, 8);
	int g = lua_tointeger(L, 9);
	int b = lua_tointeger(L, 10);
	int a = lua_tointeger(L, 11);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}

	int alphablend = lua_toboolean(L, 12);

	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8) | a;

	triangle(db, x0,y0, x1,y1, x2,y2, tp, alphablend);

	return 0;
}

static int lua_gfx_circle(lua_State *L) {
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	int radius = lua_tointeger(L, 4);

	int r = lua_tointeger(L, 5);
	int g = lua_tointeger(L, 6);
	int b = lua_tointeger(L, 7);
	int a = lua_tointeger(L, 8);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}

	int outline = lua_toboolean(L, 9);
	int alphablend = lua_toboolean(L, 10);

	if (outline) {
		if (alphablend) {
			circle_fill_aliased(db, x,y, radius, r,g,b,a, 1);
		} else {
			circle_outline(db, x,y, radius, r,g,b,a);
		}
	} else {
		if (alphablend) {
			circle_fill_aliased(db, x,y, radius, r,g,b,a, 0);
		} else {
			circle_fill(db, x,y, radius, r,g,b,a);
		}
	}

	return 0;
}

static int lua_gfx_set_px_alphablend(lua_State *L) {
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	int r = lua_tointeger(L, 4);
	int g = lua_tointeger(L, 5);
	int b = lua_tointeger(L, 6);
	int a = lua_tointeger(L, 7);

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}

	uint32_t tp = ((uint32_t)r)<<24 | ((uint32_t)g)<<16 | ((uint32_t)b)<<8 | a;
	uint32_t p = alphablend(ldb_get_px(db, x, y), tp);
	ldb_set_px(db, x, y, (p&0xFF000000)>>24, (p&0x00FF0000)>>16, (p&0x0000FF00)>>8, p&0xFF);

	return 0;
}


static int lua_gfx_rgb_to_hsv(lua_State *L) {
	int r = lua_tointeger(L, 1);
	int g = lua_tointeger(L, 2);
	int b = lua_tointeger(L, 3);

	if ( (r < 0) || (g < 0) || (b < 0) || (r > 255) || (g > 255) || (b > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b value");
		return 2;
	}

	float h=0,s=0,v=0;
	rgb_to_hsv((float)r/255.0,(float)g/255.0,(float)b/255.0,&h,&s,&v);

	lua_pushnumber(L, h);
	lua_pushnumber(L, s);
	lua_pushnumber(L, v);

	return 3;
}

static int lua_gfx_hsv_to_rgb(lua_State *L) {
	float h = lua_tonumber(L, 1);
	float s = lua_tonumber(L, 2);
	float v = lua_tonumber(L, 3);

	if ( (h < 0) || (s < 0) || (v < 0) || (h > 1) || (s > 1) || (v > 1) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid h,s,v value");
		return 2;
	}

	float r=0,g=0,b=0;
	hsv_to_rgb(h,s,v,&r,&g,&b);

	lua_pushinteger(L, (uint8_t)(r*255));
	lua_pushinteger(L, (uint8_t)(g*255));
	lua_pushinteger(L, (uint8_t)(b*255));
	//lua_pushnumber(L, r);
	//lua_pushnumber(L, g);
	//lua_pushnumber(L, b);

	return 3;
}




// when the module is require()'ed, return a table with the module functions
LUALIB_API int luaopen_ldb_gfx(lua_State *L) {
	lua_newtable(L);

	LUA_T_PUSH_S_S("version", LDB_VERSION)
	LUA_T_PUSH_S_CF("pixel_function", lua_gfx_pixel_function)
	LUA_T_PUSH_S_CF("origin_to_target", lua_gfx_origin_to_target)
	LUA_T_PUSH_S_CF("line", lua_gfx_line)
	LUA_T_PUSH_S_CF("rectangle", lua_gfx_rectangle)
	LUA_T_PUSH_S_CF("triangle", lua_gfx_triangle)
	LUA_T_PUSH_S_CF("set_px_alphablend", lua_gfx_set_px_alphablend)
	LUA_T_PUSH_S_CF("circle", lua_gfx_circle)
	LUA_T_PUSH_S_CF("floyd_steinberg", lua_gfx_floyd_steinberg)
	LUA_T_PUSH_S_CF("rgb_to_hsv", lua_gfx_rgb_to_hsv)
	LUA_T_PUSH_S_CF("hsv_to_rgb", lua_gfx_hsv_to_rgb)

	return 1;
}
