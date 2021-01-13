#include "lua.h"
#include "lauxlib.h"

#include "ldb.h"
#include "ldb_sdl.h"

#include <SDL2/SDL.h>



#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);
#define LUA_T_PUSH_S_I(S, N) lua_pushstring(L, S); lua_pushinteger(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_B(S, N) lua_pushstring(L, S); lua_pushboolean(L, N); lua_settable(L, -3);




static inline void sdl2fb_set_px(sdl2fb_t* sdl2fb, int x, int y, uint32_t sdl_p) {
	// utillity function to set a pixel on an sdl screen
	SDL_Surface *surface = sdl2fb->screen;
	uint32_t *target_pixel = (uint32_t*)((uint8_t*)surface->pixels + y*surface->pitch + x*sizeof(*target_pixel));
	*target_pixel = sdl_p;
}


static int lua_sdl2fb_tostring(lua_State *L) {
    sdl2fb_t *sdl2fb = (sdl2fb_t*)luaL_checkudata(L, 1, LDB_SDL_UDATA_NAME);
	if (sdl2fb==NULL) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a sdl2fb");
		return 2;
	}

	if (sdl2fb->window) {
		lua_pushfstring(L, "SDL2 Framebuffer: %dx%d", sdl2fb->w, sdl2fb->h);
	} else {
		lua_pushfstring(L, "SDL2 Framebuffer(Closed): %dx%d", sdl2fb->w, sdl2fb->h);
	}

    return 1;
}

static int lua_sdl2fb_close(lua_State *L) {
	sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

	SDL_Window *window = sdl2fb->window;
	if (window) {
		SDL_DestroyWindow(window);
		SDL_Quit();
		sdl2fb->window = NULL;
	}

    return 0;
}

static int lua_sdl2fb_pool_event(lua_State *L) {

	sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

	if (!sdl2fb->window) {
		lua_pushnil(L);
		lua_pushstring(L, "Atempt to :pool_event on closed sdl2fb");
		return 2;
	}

	int timeout = (int)(lua_tonumber(L, 2)*1000.0);

	SDL_Event ev;
	if (timeout <= 0) {
		// use pooling for events
		if (SDL_PollEvent(&ev) == 0) {
			return 0;
		}
	} else {
		// wait for events
		if (SDL_WaitEventTimeout(&ev, timeout) == 0) {
			return 0;
		}
	}


	//serialize SDL event to table
	lua_newtable(L);
	switch (ev.type) {
		case SDL_KEYDOWN:
			LUA_T_PUSH_S_S("type", "keydown")
			LUA_T_PUSH_S_S("scancode", SDL_GetScancodeName(ev.key.keysym.scancode))
			LUA_T_PUSH_S_S("key", SDL_GetKeyName(ev.key.keysym.sym))
			break;
		case SDL_KEYUP:
			LUA_T_PUSH_S_S("type", "keyup")
			LUA_T_PUSH_S_S("scancode", SDL_GetScancodeName(ev.key.keysym.scancode))
			LUA_T_PUSH_S_S("key", SDL_GetKeyName(ev.key.keysym.sym))
			break;
		case SDL_MOUSEMOTION:
			LUA_T_PUSH_S_S("type", "mousemotion")
			LUA_T_PUSH_S_I("x", ev.motion.x)
			LUA_T_PUSH_S_I("y", ev.motion.y)
			LUA_T_PUSH_S_I("xrel", ev.motion.xrel)
			LUA_T_PUSH_S_I("yrel", ev.motion.yrel)

			lua_pushstring(L, "buttons");
			lua_newtable(L);
			if (ev.motion.state & SDL_BUTTON(SDL_BUTTON_LEFT)) {
				LUA_T_PUSH_S_B("left", 1)
			}
			if (ev.motion.state & SDL_BUTTON(SDL_BUTTON_RIGHT)) {
				LUA_T_PUSH_S_B("right", 1)
			}
			if (ev.motion.state & SDL_BUTTON(SDL_BUTTON_MIDDLE)) {
				LUA_T_PUSH_S_B("middle", 1)
			}
			lua_settable(L, -3);

			break;
		case SDL_MOUSEBUTTONDOWN:
			LUA_T_PUSH_S_S("type", "mousebuttondown")
			LUA_T_PUSH_S_I("timestamp", ev.button.timestamp)
			LUA_T_PUSH_S_I("clicks", ev.button.clicks)
			LUA_T_PUSH_S_I("button", ev.button.button)
			LUA_T_PUSH_S_I("state", ev.button.state)
			LUA_T_PUSH_S_I("x", ev.button.x)
			LUA_T_PUSH_S_I("y", ev.button.y)
			break;
		case SDL_MOUSEBUTTONUP:
			LUA_T_PUSH_S_S("type", "mousebuttonup")
			LUA_T_PUSH_S_I("timestamp", ev.button.timestamp)
			LUA_T_PUSH_S_I("clicks", ev.button.clicks)
			LUA_T_PUSH_S_I("button", ev.button.button)
			LUA_T_PUSH_S_I("state", ev.button.state)
			LUA_T_PUSH_S_I("x", ev.button.x)
			LUA_T_PUSH_S_I("y", ev.button.y)
			break;
		case SDL_MOUSEWHEEL:
			LUA_T_PUSH_S_S("type", "mousewheel")
			LUA_T_PUSH_S_I("timestamp", ev.wheel.timestamp)
			LUA_T_PUSH_S_I("direction", ev.wheel.direction)
			LUA_T_PUSH_S_I("x", ev.wheel.x)
			LUA_T_PUSH_S_I("y", ev.wheel.y)
			break;
		case SDL_WINDOWEVENT:
			LUA_T_PUSH_S_S("type", "windowevent")
			LUA_T_PUSH_S_I("window_event", ev.window.event)
			LUA_T_PUSH_S_I("data1", ev.window.data1)
			LUA_T_PUSH_S_I("data2", ev.window.data2)
			break;
		case SDL_JOYAXISMOTION:
			LUA_T_PUSH_S_S("type", "joyaxismotion")
			break;
		case SDL_JOYBUTTONDOWN:
			LUA_T_PUSH_S_S("type", "joybuttondown")
			LUA_T_PUSH_S_I("timestamp", ev.jbutton.timestamp)
			LUA_T_PUSH_S_I("joystick", ev.jbutton.which)
			LUA_T_PUSH_S_I("button", ev.jbutton.button)
			LUA_T_PUSH_S_I("state", ev.jbutton.state)
			break;
		case SDL_JOYBUTTONUP:
			LUA_T_PUSH_S_S("type", "joybuttonup")
			LUA_T_PUSH_S_I("timestamp", ev.jbutton.timestamp)
			LUA_T_PUSH_S_I("joystick", ev.jbutton.which)
			LUA_T_PUSH_S_I("button", ev.jbutton.button)
			LUA_T_PUSH_S_I("state", ev.jbutton.state)
			break;
		case SDL_QUIT:
			LUA_T_PUSH_S_S("type", "quit")
			break;
		default:
			LUA_T_PUSH_S_I("type", ev.type)
			break;
	}

    return 1;
}

static int lua_sdl2fb_set_mouse_grab(lua_State *L) {
    sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

	SDL_bool grab = lua_toboolean(L, 2);

	SDL_SetRelativeMouseMode(grab);

    return 0;
}

static int lua_sdl2fb_draw_from_drawbuffer(lua_State *L) {
    sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

    drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 2, db)

	SDL_Window *window = sdl2fb->window;
	SDL_Surface *screen = sdl2fb->screen;

	if (!sdl2fb->window || !sdl2fb->screen) {
		return 0;
	}

    int x = lua_tointeger(L, 3);
    int y = lua_tointeger(L, 4);
    int cx,cy;
    uint32_t sp, sdl_p;

	SDL_LockSurface(screen);

	if ( (x==0) && (y==0) && (db->pxfmt == LDB_PXFMT_32BPP_ABGR) && (screen->w == db->w) && (screen->h == db->h) ) {
		SDL_ConvertPixels(screen->w, screen->h, SDL_PIXELFORMAT_RGBA8888, db->data, db->w*4, screen->format->format, screen->pixels, screen->pitch);
	} else {
		for (cy=0; cy < db->h; cy++) {
	        for (cx=0; cx < db->w; cx++) {
	            if (x+cx < 0 || y+cy < 0 || x+cx >= sdl2fb->w || y+cy >= sdl2fb->h) {
	                continue;
	            } else {
					sp = get_px(db->data, db->w, cx,cy, db->pxfmt);
					sdl_p = SDL_MapRGBA(screen->format, (sp&0xFF000000)>>24, (sp&0x00FF0000)>>16, (sp&0x0000FF00)>>8, sp&0xff);
					sdl2fb_set_px(sdl2fb, cx+x,cy+y, sdl_p);
	            }
	        }
	    }
	}

	SDL_UnlockSurface(screen);

    SDL_UpdateWindowSurface(window);

    return 0;

}

void sdl2db_close_func(void* data) {
	drawbuffer_t *db = (drawbuffer_t*)data;
	sdl2fb_t *sdl2fb = db->close_data;

	SDL_Window *window = sdl2fb->window;
	if (window) {
		//SDL_DestroyRenderer(sdl2fb->renderer);
		SDL_DestroyWindow(window);
		SDL_Quit();
		sdl2fb->window = NULL;
		//sdl2fb->renderer = NULL;
		db->data = NULL;
	}
}

static int lua_sdl2fb_get_drawbuffer(lua_State *L) {
	sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

	// Create new drawbuffer userdata object
	drawbuffer_t *db = (drawbuffer_t *)lua_newuserdata(L, sizeof(drawbuffer_t));

	db->w = sdl2fb->w;
	db->h = sdl2fb->h;

	// TODO: Check pixel format and pitch from SDL surface for compabillity, maybe suppoprt all pixel formats supported by ldb.
	db->pxfmt = LDB_PXFMT_32BPP_BGRA;
	db->data = sdl2fb->screen->pixels;
	db->close_func = &sdl2db_close_func;
	db->close_data = sdl2fb;

	// apply the drawbuffer metatable to it
	lua_set_ldb_meta(L, -2);

	// return created drawbuffer
	return 1;
}

static int lua_sdl2fb_update_drawbuffer(lua_State *L) {
	sdl2fb_t *sdl2fb;
	CHECK_SDL2FB(L, 1, sdl2fb)

	SDL_Window *window = sdl2fb->window;
	SDL_UpdateWindowSurface(window);

	return 0;
}

static int lua_sdl_new_sdl2fb(lua_State *L) {
    int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);
	const char *title = lua_tostring(L, 3);
	if (!title) {
		title = "ldb_sdl";
	}
	if ((w<=0) || (h<=0)) {
		lua_pushnil(L);
		lua_pushstring(L, "width and height must be >0");
		return 2;
	}

	sdl2fb_t *sdl2fb = (sdl2fb_t *)lua_newuserdata(L, sizeof(sdl2fb_t));

	SDL_Window *window;
	SDL_Surface *screen;
	//SDL_Renderer *renderer;
	//SDL_Texture *texture;

	SDL_Init(SDL_INIT_VIDEO);
	//SDL_Init(SDL_INIT_EVERYTHING);
	window = SDL_CreateWindow(title,0, 0, w, h, 0);
	if (!window) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't create SDL2 window!");
		return 2;
	}
	screen = SDL_GetWindowSurface(window);
	if (!screen) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't get SDL2 screen!");
		return 2;
	}

	/*
	renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED );
	if (!renderer) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't create SDL2 renderer!");
		return 2;
	}
	texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, w, h);
	if (!renderer) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't create SDL2 texture!");
		return 2;
	}
	*/



	sdl2fb->window = window;
	sdl2fb->screen = screen;
	//sdl2fb->renderer = renderer;
	//sdl2fb->texture = texture;
	sdl2fb->w = w;
	sdl2fb->h = h;

	// push/create metatable for sdl2fb userdata. The same metatable is used for every sdl2fb instance.
    if (luaL_newmetatable(L, LDB_SDL_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("draw_from_drawbuffer", lua_sdl2fb_draw_from_drawbuffer)
		LUA_T_PUSH_S_CF("pool_event", lua_sdl2fb_pool_event)
		LUA_T_PUSH_S_CF("set_mouse_grab", lua_sdl2fb_set_mouse_grab)
		LUA_T_PUSH_S_CF("get_drawbuffer", lua_sdl2fb_get_drawbuffer)
		LUA_T_PUSH_S_CF("update_drawbuffer", lua_sdl2fb_update_drawbuffer)
		LUA_T_PUSH_S_CF("close", lua_sdl2fb_close)
		LUA_T_PUSH_S_CF("tostring", lua_sdl2fb_tostring)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_sdl2fb_close)
		LUA_T_PUSH_S_CF("__tostring", lua_sdl2fb_tostring)
	}

	// apply metatable to userdata
    lua_setmetatable(L, -2);

	// return userdata
    return 1;
}




LUALIB_API int luaopen_ldb_sdl(lua_State *L) {
    lua_newtable(L);

    LUA_T_PUSH_S_S("version", LDB_VERSION)
    LUA_T_PUSH_S_CF("new_sdl2fb", lua_sdl_new_sdl2fb)

    return 1;
}
