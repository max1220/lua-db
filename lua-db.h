#define CHECK_DB(L, I, D) D=(drawbuffer_t *)luaL_checkudata(L, I, "drawbuffer"); if (D==NULL) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a drawbuffer", I); return 2; }

// you should read this as an if statement, checking if the pixel is in bounds, only then setting the pixel
#define DB_SET_PX(D,X,Y,P) \
	( \
	( ((Y) >= (D)->h) || ((Y) < 0) ) ? \
		( P ) \
	: \
		( \
		( ((X) >= (D)->w) || ((X) < 0)) ? \
			( P ) \
		: \
			( (D)->data[(Y)*(D)->w+(X)] = (P) ) \
		) \
	);


// you should read this as an if statement, checking if the pixel is in bounds, only then reading and returning the pixel, or a 0,0,0,0 pixel otherwise
#define DB_GET_PX(D,X,Y) \
	( \
	( ((Y) >= (D)->h) || ((Y) < 0) ) ? \
		( (pixel_t){0,0,0,0} ) \
	: \
		( \
		( ((X) >= (D)->w) || ((X) < 0)) ? \
			( (pixel_t){0,0,0,0} ) \
		: \
			( ((D)->data[(Y)*(D)->w+(X)]) ) \
		) \
	);




typedef struct {
    uint8_t r, g, b, a;
} pixel_t;

typedef struct {
    uint16_t w, h;
    uint32_t len;
    pixel_t *data;
} drawbuffer_t;
