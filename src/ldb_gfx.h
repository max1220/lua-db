#ifndef LUA_LDB_GFX_H
#define LUA_LDB_GFX_H


// Macro to set a pixel with compile-time parameters specifying alpha-blending and scale
// Keep ALPHA and SX,SY compile-time constant!
#define SET_PX(ALPHA,SX,SY, DB,X,Y,P) for (int __cy = 0; __cy<SX; __cy++) { for (int __cx = 0; __cx<SY; __cx++) { \
	if (ALPHA==1) { db_set_px_ignorealpha(DB, X+__cx, Y+__cy, P); } \
	else if (ALPHA==2) { db_set_px_alphablend(DB, X+__cx, Y+__cy, P); } \
	else { db_set_px(DB, X+__cx, Y+__cy, P); } } }

// Macro to copy a rectangular region with compile-time parameters specifying alpha-blending and scale
// Keep ALPHA and SX,SY compile-time constant!
#define COPY_RECT(ALPHA,SX,SY, O_DB,T_DB, TX,TY, OX,OY, W,H) for (int __cy = 0; __cy<H; __cy++) { for (int __cx = 0; __cx<W; __cx++) { \
	uint32_t __p = db_get_px(O_DB, OX+__cx, OY+__cy); \
	SET_PX(ALPHA, SX,SY, T_DB, TX+__cx,TY+__cy, __p) } }


// Mix the colors based on the alph value of the target pixel
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

// Set a pixel by mixing the color values using alpha-blending
static inline void set_px_alphablend(uint8_t* data, int w, int x, int y, uint32_t p, PIX_FMT fmt) {
	uint32_t sp = get_px(data, w, x,y, fmt);
	uint32_t tp = alphablend(sp, p);
	set_px(data, w, x, y, tp, fmt);
}
static inline void db_set_px_alphablend(const drawbuffer_t* target_db, int x, int y, uint32_t p) {
	if ((x<0) || (y<0) || (x>=target_db->w) || (y>=target_db->h) || (!target_db->data)) {
		return;
	}
	set_px_alphablend(target_db->data, target_db->w, x, y, p, target_db->pxfmt);
}

// Set a pixel only if the alpha-value is >0
static inline void set_px_ignorealpha(uint8_t* data, int w, int x, int y, uint32_t p, PIX_FMT fmt) {
	if (unpack_pixel_a(p)) {
		set_px(data, w, x, y, p, fmt);
	}
}
static inline void db_set_px_ignorealpha(const drawbuffer_t* target_db, int x, int y, uint32_t p) {
	if ((x<0) || (y<0) || (x>=target_db->w) || (y>=target_db->h) || (!target_db->data)) {
		return;
	}
	set_px_ignorealpha(target_db->data, target_db->w, x, y, p, target_db->pxfmt);
}

// Convert rgb <-> hsv
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




#endif
