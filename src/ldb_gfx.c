#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>


#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"
#include "ldb_gfx.h"


#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_I_S(N, S) lua_pushinteger(L, N) lua_pushstring(L, S); lua_settable(L, -3);





// copy a rectangular region from the origin_db to the target_db
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

	// TODO: Allow non-integer scale using bilinear interpolation
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

	// avoid runtime-checks in hotloop by using COPY_RECT macro and having alpha-mode and scale constant during compilation
	if (alpha_mode == 0) {
		if ((scale_x>1) || (scale_y>1)) {
			COPY_RECT(0, scale_x, scale_y, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		} else {
			COPY_RECT(0, 1, 1, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		}
	} else if (alpha_mode == 1) {
		if ((scale_x>1) || (scale_y>1)) {
			COPY_RECT(1, scale_x, scale_y, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		} else {
			COPY_RECT(1, 1, 1, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		}
	} else if (alpha_mode == 2) {
		if ((scale_x>1) || (scale_y>1)) {
			COPY_RECT(2, scale_x, scale_y, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		} else {
			COPY_RECT(2, 1, 1, origin_db, target_db, target_x, target_y, origin_x, origin_y, w, h)
		}
	}

	return 0;
}



// utillity function for floyd_steinberg dithering. Increment pixel by error * weight
static inline void floyd_steinberg_increment_pixel(uint8_t* data, int w, PIX_FMT fmt, int x, int y, uint8_t weight, uint8_t r_err, uint8_t g_err, uint8_t b_err) {
	uint32_t p = get_px(data, w, x, y, fmt);
	uint32_t r, g, b, a;
	UNPACK_RGBA(p,r,g,b,a)

	r += (r_err*weight)>>4;
	g += (g_err*weight)>>4;
	b += (b_err*weight)>>4;
	set_px(data, w, x,y, pack_pixel_rgba(r>255?255:r, g>255?255:g, b>255?255:b, a), fmt);
}

// perform floyd_steinberg dithering to reduce the color bits per pixel. rmask/gmask/bmask are the pixel bits to keep.
static inline void floyd_steinberg(const drawbuffer_t* db, uint8_t rmask, uint8_t gmask, uint8_t bmask) {
	int cx,cy;
	uint32_t sp,tp;
	uint8_t r,g,b;
	uint8_t r_err, g_err, b_err;

	for (cy=0; cy < db->h; cy++) {
		for (cx=0; cx < db->w; cx++) {
			sp = get_px(db->data, db->w, cx,cy, db->pxfmt);
			UNPACK_RGB(sp, r,g,b)
			tp = pack_pixel_rgb(r&rmask,g&gmask,b&bmask);
			set_px(db->data, db->w, cx,cy,tp, db->pxfmt);
			r_err = r&(!rmask);
			g_err = g&(!gmask);
			b_err = b&(!bmask);
			floyd_steinberg_increment_pixel(db->data, db->w, db->pxfmt, cx+1, cy  , 7, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db->data, db->w, db->pxfmt, cx-1, cy+1, 3, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db->data, db->w, db->pxfmt, cx  , cy+1, 5, r_err, g_err, b_err);
			floyd_steinberg_increment_pixel(db->data, db->w, db->pxfmt, cx+1, cy+1, 1, r_err, g_err, b_err);
		}
	}
}

// perform floyd_steinberg dithering on a drawbuffer from Lua
static int lua_gfx_floyd_steinberg(lua_State *L) {
	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 1, db)

	if (lua_isnumber(L, 3) && lua_isnumber(L, 4)) {
		// lua arguments 2,3,4 are bitmasks
		floyd_steinberg(db, lua_tointeger(L, 2), lua_tointeger(L, 3), lua_tointeger(L, 4));
	} else if (lua_tointeger(L, 2)==1) {
		floyd_steinberg(db, 0x80, 0x80, 0x80); // 1bpp
	} else if (lua_tointeger(L, 2)==8) {
		floyd_steinberg(db, 0xe0, 0xe0, 0xc0); // 8bpp rgb332
	} else if (lua_tointeger(L, 2)==16) {
		floyd_steinberg(db, 0xf8, 0xfc, 0xf8); // 16bpp 565
	} else {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown bpp/no mask! Dithering is only supported for 1bpp, 8bpp and 16bpp or using a bitmask for each channel.");
		return 2;
	}

	lua_pushboolean(L, 1);
	return 1;
}



// get the distance of point (px,py) to a capsule(line with width=r/2, from (ax,ay) to (bx,by))
static inline float capsuleSDF(float px, float py, float ax, float ay, float bx, float by, float r) {
    float pax = px - ax, pay = py - ay, bax = bx - ax, bay = by - ay;
    float h = fmaxf(fminf((pax * bax + pay * bay) / (bax * bax + bay * bay), 1.0f), 0.0f);
    float dx = pax - bax * h, dy = pay - bay * h;
    return sqrtf(dx * dx + dy * dy) - r;
}

// draw a smooth line by using a signed distance function to color the border region with reduces alpha(No "jagged edges", but expensive)
static inline void line_smooth(uint8_t* data, int w, int h, PIX_FMT fmt, float x0, float y0, float x1, float y1, uint32_t p, float radius) {
	float alpha;
	int cx, cy;
	float a = p & 0xff;

    int x_min = (int)floorf(fminf(x0, x1) - radius);
    int x_max = (int) ceilf(fmaxf(x0, x1) + radius);
    int y_min = (int)floorf(fminf(y0, y1) - radius);
    int y_max = (int) ceilf(fmaxf(y0, y1) + radius);

	// clamp to screen region
	x_min = (x_min<0) ? 0 : ((x_min>=w) ? w-1 : x_min);
	x_max = (x_max<0) ? 0 : ((x_max>=w) ? w-1 : x_max);
	y_min = (y_min<0) ? 0 : ((y_min>=h) ? h-1 : y_min);
	y_max = (y_max<0) ? 0 : ((y_max>=h) ? h-1 : y_max);

    for (cy = y_min; cy <= y_max; cy++) {
		for (cx = x_min; cx <= x_max; cx++) {
			alpha = fmaxf(fminf(0.5f - capsuleSDF(cx, cy, x0, y0, x1, y1, radius), 1.0f), 0.0f)*(float)a;
			if (alpha>0) {
				set_px_alphablend(data, w, cx,cy, (p&0xffffff00) | (uint32_t)alpha, fmt);
			}
		}
	}
}

// draw a line, set color
static inline void line(const drawbuffer_t* db, int x0, int y0, int x1, int y1, int dx, int dy, int sx, int sy, int err, uint32_t p){
	int err2;
	while(1) {
		db_set_px(db, x0,y0,p);
		if (x0==x1 && y0==y1) {
			break;
		}
		err2 = err;
		if (err2 > -dx) {
			err -= dy;
			x0 += sx;
		}
		if (err2 < dy) {
			err += dx;
			y0 += sy;
		}
	}
}

// draw a line, use alphablending
static inline void line_alphablend(const drawbuffer_t* db, int x0, int y0, int x1, int y1, int dx, int dy, int sx, int sy, int err, uint32_t p) {
	int err2;
	while(1) {
		db_set_px_alphablend(db, x0,y0,p);
		if (x0==x1 && y0==y1) {
			break;
		}
		err2 = err;
		if (err2 > -dx) {
			err -= dy;
			x0 += sx;
		}
		if (err2 < dy) {
			err += dx;
			y0 += sy;
		}
	}
}

// draw a line on a drawbuffer
static inline void db_line(const drawbuffer_t* db, int x0, int y0, int x1, int y1, uint32_t p, int alphablend) {
	int dx = abs(x1-x0);
	int dy = abs(y1-y0);
	int sx = (x0<x1 ? 1 : -1);
	int sy = (y0<y1 ? 1 : -1);
	int err = (dx>dy ? dx : -dy)/2;
	if (alphablend) {
		line_alphablend(db, x0, y0, x1, y1, dx, dy, sx, sy, err, p);
	} else {
		line(db, x0, y0, x1, y1, dx, dy, sx, sy, err, p);
	}
}

// draw a line on a drawbuffer from Lua
static int lua_gfx_line(lua_State *L) {
	drawbuffer_t* db;
	LUA_LDB_CHECK_DB(L, 1, db)

	float x0 = lua_tonumber(L, 2);
	float y0 = lua_tonumber(L, 3);
	float x1 = lua_tonumber(L, 4);
	float y1 = lua_tonumber(L, 5);

	// the integer coordinates are for the pixel-centers
	int ix0 = x0+0.5;
	int iy0 = y0+0.5;
	int ix1 = x1+0.5;
	int iy1 = y1+0.5;

	int r = lua_tointeger(L, 6);
	int g = lua_tointeger(L, 7);
	int b = lua_tointeger(L, 8);
	int a = lua_tointeger(L, 9);
	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) ) {
		lua_pushnil(L);
		lua_pushstring(L, "invalid r,g,b,a value");
		return 2;
	}
	uint32_t tp = pack_pixel_rgba(r,g,b,a);

	float radius;
	if (lua_isnumber(L, 10)) {
		// draw using capsule signed distance function and alphablending(smooth edge)
		// the SDF supports float coordinates in a usefull way
		radius = lua_tonumber(L, 10);
		if (radius <= 0) {
			radius = 1;
		}
		line_smooth(db->data, db->w, db->h, db->pxfmt, x0, y0, x1, y1, tp, radius);
		return 0;
	} else {
		// draw using Bresenham
		db_line(db, ix0, iy0, ix1, iy1, tp, lua_toboolean(L, 10));
		return 0;
	}
}



// set xmin,xmax,ymin,ymax to corresponding values in x0,y0,x1,y1, and clamp coordinates to drawbuffer dimensions
static inline void rectangle_args_prep(const drawbuffer_t* db, int x0, int y0, int x1, int y1, int* xmin, int* xmax, int* ymin, int* ymax) {
	x0 = (x0<0) ? 0 : x0;
	x0 = (x0>=db->w) ? (db->w-1) : x0;
	y0 = (y0<0) ? 0 : y0;
	y0 = (y0>=db->h) ? (db->h-1) : y0;
	x1 = (x1<0) ? 0 : x1;
	x1 = (x1>=db->w) ? (db->w-1) : x1;
	y1 = (y1<0) ? 0 : y1;
	y1 = (y1>=db->h) ? (db->h-1) : y1;
	*xmin = (x0<x1) ? x0 : x1;
	*xmax = (x0<x1) ? x1 : x0;
	*ymin = (y0<y1) ? y0 : y1;
	*ymax = (y0<y1) ? y1 : y0;
}

static inline void rectangle_fill(uint8_t* data, int w, PIX_FMT fmt, int xmin, int ymin, int xmax, int ymax, uint32_t p) {
	for (int cy = ymin; cy < ymax; cy++) {
		for (int cx = xmin; cx < xmax; cx++) {
			set_px(data, w, cx,cy, p, fmt);
		}
	}
}
static inline void rectangle_fill_alphablend(uint8_t* data, int w, PIX_FMT fmt, int xmin, int ymin, int xmax, int ymax, uint32_t p) {
	for (int cy = ymin; cy < ymax; cy++) {
		for (int cx = xmin; cx < xmax; cx++) {
			set_px_alphablend(data, w, cx,cy, p, fmt);
		}
	}
}
static inline void db_rectangle_fill(const drawbuffer_t* db, int x0, int y0, int x1, int y1, uint32_t p, int alphablend) {
	int xmin,xmax,ymin,ymax;
	rectangle_args_prep(db, x0,y0,x1,y1, &xmin,&xmax,&ymin,&ymax);

	if (alphablend) {
		rectangle_fill_alphablend(db->data, db->w, db->pxfmt, xmin, ymin, xmax,ymax, p);
	} else {
		rectangle_fill(db->data, db->w, db->pxfmt, xmin, ymin, xmax,ymax, p);
	}
}

static inline void rectangle_outline(uint8_t* data, int w, PIX_FMT fmt, int xmin, int ymin, int xmax, int ymax, uint32_t p) {
	for (int cx = xmin; cx < xmax; cx++) {
		set_px(data, w, cx,ymin, p, fmt);
		set_px(data, w, cx,ymax, p, fmt);
	}
	for (int cy = ymin; cy < ymax; cy++) {
		set_px(data, w, xmin,cy, p, fmt);
		set_px(data, w, xmax,cy, p, fmt);
	}
}
static inline void rectangle_outline_alphablend(uint8_t* data, int w, PIX_FMT fmt, int xmin, int ymin, int xmax, int ymax, uint32_t p) {
	for (int cx = xmin; cx < xmax; cx++) {
		set_px_alphablend(data, w, cx,ymin, p, fmt);
		set_px_alphablend(data, w, cx,ymax, p, fmt);
	}
	for (int cy = ymin; cy < ymax; cy++) {
		set_px_alphablend(data, w, xmin,cy, p, fmt);
		set_px_alphablend(data, w, xmax,cy, p, fmt);
	}
}
static inline void db_rectangle_outline(const drawbuffer_t* db, int x0, int y0, int x1, int y1, uint32_t p, int alphablend) {
	int xmin,xmax,ymin,ymax;
	rectangle_args_prep(db, x0,y0,x1,y1, &xmin,&xmax,&ymin,&ymax);

	if (alphablend) {
		rectangle_outline_alphablend(db->data, db->w, db->pxfmt, xmin, ymin, xmax,ymax, p);
	} else {
		rectangle_outline(db->data, db->w, db->pxfmt, xmin, ymin, xmax,ymax, p);
	}
}

// draw a rectangle in a drawbuffer from Lua
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
	uint32_t p = pack_pixel_rgba(r,g,b,a);

	int outline = lua_toboolean(L, 10);
	int alphablend = lua_toboolean(L, 11);

	if (outline) {
		db_rectangle_outline(db, x, y, x+w, y+h, p, alphablend);
	} else {
		db_rectangle_fill(db, x, y, x+w, y+h, p, alphablend);
	}

	return 0;
}










// prepare arguments for setting a vertical line. Check agains width to safely set pixels.
static inline void set_vline_args_prep(int w, float x0, float x1, int* xmin, int* xmax) {
	*xmin = (x0 < x1) ? x0 : x1;
	*xmax = (x0 > x1) ? x0 : x1;
	*xmin = (*xmin < 0) ? 0 : *xmin;
	*xmin = (*xmin >= w) ? w-1 : *xmin;
	*xmax = (*xmax < 0) ? 0 : *xmax;
	*xmax = (*xmax >= w) ? w-1 : *xmax;
}

static inline void set_vline(uint8_t* data, int w, PIX_FMT fmt, int y, float x0, float x1, uint32_t tp) {
	int xmin,xmax;
	set_vline_args_prep(w, x0, x1, &xmin, &xmax);
	for (int cx=xmin; cx<=xmax; cx++) {
		set_px(data, w, cx, y, tp, fmt);
	}
}

static inline void set_vline_alphablend(uint8_t* data, int w, PIX_FMT fmt, int y, float x0, float x1, uint32_t tp) {
	int xmin,xmax;
	set_vline_args_prep(w, x0, x1, &xmin, &xmax);
	for (int cx=xmin; cx<=xmax; cx++) {
		set_px_alphablend(data, w, cx, y, tp, fmt);
	}
}

// fill the flat(at the top) triangle. vertice y must be ascending.
static inline void triangle_top(uint8_t* data, int w, int h, PIX_FMT fmt, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp, int alphablend) {
	float slope1 = (x2-x0)/(y2-y0);
	float slope2 = (x2-x1)/(y2-y1);
	float cx1 = x2;
	float cx2 = x2;

	void (*set_vline_ptr)(uint8_t*, int, PIX_FMT, int, float, float, uint32_t) = &set_vline;
	if (alphablend) {
		set_vline_ptr = &set_vline_alphablend;
	}

	for (int cy=y2; cy>=y0; cy--) {
		if ((cy>=0)&&(cy<h)) {
			set_vline_ptr(data, w, fmt, cy, cx1, cx2, tp);
		}
		cx1 -= slope1;
		cx2 -= slope2;
	}
}

// fill the flat(at the bottom) triangle. vertice y must be ascending.
static inline void triangle_bottom(uint8_t* data, int w, int h, PIX_FMT fmt, float x0, float y0, float x1, float y1, float x2, float y2, uint32_t tp, int alphablend) {
	float slope1 = (x1-x0) / (y1-y0);
	float slope2 = (x2-x0) / (y2-y0);
	float cx1 = x0;
	float cx2 = x0;

	void (*set_vline_ptr)(uint8_t*, int, PIX_FMT, int, float, float, uint32_t) = &set_vline;
	if (alphablend) {
		set_vline_ptr = &set_vline_alphablend;
	}

	for (int cy=y0; cy<=y1; cy++) {
		if ((cy>=0)&&(cy<h)) {
			set_vline_ptr(data, w, fmt, cy, cx1, cx2, tp);
		}
		cx1 += slope1;
		cx2 += slope2;
	}
}

static void triangle_args_prep(int* x0, int* y0, int* x1, int* y1, int* x2, int* y2, int* split) {
	// sort by y
	int tmp_x, tmp_y;
	if (y0 > y2) {
		tmp_x = *x0; *x0 = *x2; *x2 = tmp_x;
		tmp_y = *y0; *y0 = *y2; *y2 = tmp_y;
	}
	if (y0 > y1) {
		tmp_x = *x0; *x0 = *x1; *x1 = tmp_x;
		tmp_y = *y0; *y0 = *y1; *y1 = tmp_y;
	}
	if (y1 > y2) {
		tmp_x = *x1; *x1 = *x2; *x2 = tmp_x;
		tmp_y = *y1; *y1 = *y2; *y2 = tmp_y;
	}

	// calculate top/bottom split
	*split = (int)(*x0 + ((float)(*y1 - *y0) / (float)(*y2 - *y0)) * (*x2 - *x0));
}

static inline void triangle(const drawbuffer_t* db, int x0, int y0, int x1, int y1, int x2, int y2, uint32_t tp, int alphablend) {
	int split;
	triangle_args_prep(&x0,&y0,&x1,&y1,&x2,&y2,&split);

	// check if triangle is visible
	if (((y0 < 0) && (y2 < 0)) || ((y0 >= db->h) && (y2 >= db->h))) {
		return;
	}

	if (y1==y2) {
		triangle_bottom(db->data, db->w, db->h, db->pxfmt, x0,y0, x1,y1, x2,y2, tp, alphablend);
	} else if (y0==y1) {
		triangle_top(db->data, db->w, db->h, db->pxfmt, x0,y0, x1,y1, x2,y2, tp, alphablend);
	} else {
		triangle_bottom(db->data, db->w, db->h, db->pxfmt, x0,y0, x1,y1, split,y1, tp, alphablend);
		triangle_top(db->data, db->w, db->h, db->pxfmt, x1,y1, split,y1, x2,y2, tp, alphablend);
	}
}

// draw a triangle on a drawbuffer from Lua
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
	triangle(db, x0,y0, x1,y1, x2,y2, pack_pixel_rgba(r,g,b,a), alphablend);

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

	if ( (r < 0) || (g < 0) || (b < 0) || (a < 0) || (r > 255) || (g > 255) || (b > 255) || (a > 255) || (x<0) || (y<0) || (x>=db->w) || (y>=db->h)) {
		return 0;
	}

	db_set_px_alphablend(db, x,y, pack_pixel_rgba(r,g,b,a));

	lua_pushboolean(L, 1);
	return 1;
}


static int lua_gfx_rgb_to_hsv(lua_State *L) {
	int r = lua_tointeger(L, 1);
	int g = lua_tointeger(L, 2);
	int b = lua_tointeger(L, 3);

	if ( (r < 0) || (g < 0) || (b < 0) || (r > 255) || (g > 255) || (b > 255) ) {
		return 0;
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
	h = ((h>1)||(h<0)) ? fmodf(h, 1.0) : h;
	if ((s<0) || (s>1) || (v<0) || (v>1)) {
		return 0;
	}

	float r=0,g=0,b=0;
	hsv_to_rgb(h,s,v,&r,&g,&b);

	lua_pushinteger(L, (uint8_t)(r*255));
	lua_pushinteger(L, (uint8_t)(g*255));
	lua_pushinteger(L, (uint8_t)(b*255));

	return 3;
}



static inline float circleSDF(float px, float py, float cx, float cy, float r) {
	float dx = px-cx;
	float dy = py-cy;
    return sqrtf(dx*dx + dy*dy) - r;
}

static inline void draw_circle_sdf(uint8_t* data, int w, int h, PIX_FMT fmt, float center_x, float center_y, float radius, uint8_t r, uint8_t g, uint8_t b, uint8_t a, int outline) {
	float alpha, d;
	uint32_t sp, p;
	int cx, cy;
	uint32_t tp = ((uint32_t)r<<24) | ((uint32_t)g<<16) | ((uint32_t)b<<8);

	int x_min = (int)floorf(center_x-radius);
	int x_max = (int) ceilf(center_x+radius);
	int y_min = (int)floorf(center_y-radius);
	int y_max = (int) ceilf(center_y+radius);

	// clamp to screen region
	x_min = (x_min<0) ? 0 : ((x_min>=w) ? w-1 : x_min);
	x_max = (x_max<0) ? 0 : ((x_max>=w) ? w-1 : x_max);
	y_min = (y_min<0) ? 0 : ((y_min>=h) ? h-1 : y_min);
	y_max = (y_max<0) ? 0 : ((y_max>=h) ? h-1 : y_max);

    for (cy = y_min; cy <= y_max; cy++) {
		for (cx = x_min; cx <= x_max; cx++) {
			d = circleSDF(cx, cy, center_x, center_y, radius);
			if (outline && (d<0)) {
				d = -d;
			}
			alpha = fmaxf(fminf(0.5f - d, 1.0f), 0.0f)*(float)a;
			if (alpha>0) {
				set_px_alphablend(data,w,cx,cy,tp | ((uint32_t)alpha),fmt);
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
        	db_set_px_rgba(db, x + tx, y + ty, r,g,b,a);
		}
	}
}

static inline void circle_set8(drawbuffer_t* db, int x, int y, int cx, int cy, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	db_set_px_rgba(db, x+cx, y+cy, r,g,b,a);
    db_set_px_rgba(db, x-cx, y+cy, r,g,b,a);
    db_set_px_rgba(db, x+cx, y-cy, r,g,b,a);
    db_set_px_rgba(db, x-cx, y-cy, r,g,b,a);
    db_set_px_rgba(db, x+cy, y+cx, r,g,b,a);
    db_set_px_rgba(db, x-cy, y+cx, r,g,b,a);
    db_set_px_rgba(db, x+cy, y-cx, r,g,b,a);
    db_set_px_rgba(db, x-cy, y-cx, r,g,b,a);
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
			draw_circle_sdf(db->data, db->w, db->h, db->pxfmt, x,y, radius, r,g,b,a, 1);
		} else {
			circle_outline(db, x,y, radius, r,g,b,a);
		}
	} else {
		if (alphablend) {
			draw_circle_sdf(db->data, db->w, db->h, db->pxfmt, x,y, radius, r,g,b,a, 0);
		} else {
			circle_fill(db, x,y, radius, r,g,b,a);
		}
	}

	return 0;
}





// when the module is require()'ed, return a table with the module functions
LUALIB_API int luaopen_ldb_gfx(lua_State *L) {
	lua_newtable(L);

	LUA_T_PUSH_S_S("version", LDB_VERSION)
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
