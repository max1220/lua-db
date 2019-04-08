#define CHECK_DB(L, I, D) D=(drawbuffer_t *)luaL_checkudata(L, I, "drawbuffer"); if (D==NULL) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a drawbuffer", I); return 2; }
#define DB_SET_PX(D,X,Y,P) D->data[Y*D->w+X] = P;
#define DB_GET_PX(D,X,Y) (D)->data[(Y)*(D)->w+(X)];

typedef struct {
    uint8_t r, g, b, a;
} pixel_t;

typedef struct {
    uint16_t w, h;
    uint32_t len;
    pixel_t *data;
} drawbuffer_t;
