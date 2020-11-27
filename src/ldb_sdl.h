#ifndef LUA_LDB_SDL_H
#define LUA_LDB_SDL_H

#define LDB_SDL_UDATA_NAME "sdl2fb"
#include <SDL2/SDL.h>

#define CHECK_SDL2FB(L, I, D) D=(sdl2fb_t *)luaL_checkudata(L, I, LDB_SDL_UDATA_NAME); if ((D==NULL) || (!D->window)) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a sdl2fb", I); return 2; }

typedef struct {
    SDL_Window *window;
	SDL_Surface *screen;
	//SDL_Renderer *renderer;
	//SDL_Texture *texture;
	uint16_t w;
	uint16_t h;
} sdl2fb_t;




#endif
