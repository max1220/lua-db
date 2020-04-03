


# Global configuration
#CFLAGS = -g -fPIC -std=c99 -Wall -Wextra -Wpedantic
CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic -march=native -mtune=native
LIBFLAG = -shared -fpic -lm -Wl,--as-needed

# Lua configuration
LUA_CFLAGS = -I/usr/include/lua5.1
LUA_LIBS = -llua5.1

# SDL2 Module configuration
SDL_CFLAGS = -I/usr/include/SDL2
SDL_LIBS = -lSDL2
#SDL_CFLAGS = $(sdl2-config --cflags)
#SDL_LIBS = $(sdl2-config --libs)


STRIP = strip

.PHONY: all
all: core module_fb module_sdl module_gfx

.PHONY: help
help:
	@echo "Available make targets: "
	@echo " help (this message)"
	@echo " all (build ldb and all modules)"
	@echo " core (only build core module)"
	@echo " module_gfx (only build extended graphics primitives module)"
	@echo " module_sdl (only build sdl module)"
	@echo " module_fb (only build framebuffer module)"
	@echo " clean (remove build artifacts)"

.PHONY: core
core: ldb_core.so
	#$(STRIP) $^
	@echo "-> Building core module finished"

.PHONY: module_gfx
module_gfx: ldb_gfx.so
	#$(STRIP) $^
	@echo "-> Building extended graphics primitives module finished"

.PHONY: module_sdl
module_sdl: ldb_sdl.so
	#$(STRIP) $^
	@echo "-> Building SDL2 module finished"

.PHONY: module_fb
module_fb: ldb_fb.so
	#$(STRIP) $^
	@echo "-> Building Framebuffer module finished"

.PHONY: clean
clean:
	rm -f ldb_core.o ldb_gfx.o ldb_sdl.o
	rm -f ldb_core.so ldb_gfx.so ldb_sdl.so ldb_fb.so

ldb_core.o: ldb_core.c
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) -c $^

ldb_core.so: ldb_core.o
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $^ $(LIBFLAG) $(LUA_LIBS)



ldb_gfx.o: ldb_gfx.c
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) -c $^

ldb_gfx.so: ldb_gfx.o ldb_core.o
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $^ $(LIBFLAG) $(LUA_LIBS)



ldb_sdl.o: ldb_sdl.c
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $(SDL_CFLAGS) -c $^

ldb_sdl.so: ldb_sdl.o ldb_core.o
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $(SDL_CFLAGS) $^ $(LIBFLAG) $(LUA_LIBS) $(SDL_LIBS)



ldb_fb.o: ldb_fb.c
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $(SDL_CFLAGS) -c $^

ldb_fb.so: ldb_fb.o ldb_core.o
	$(CC) -o $@ $(CFLAGS) $(LUA_CFLAGS) $(SDL_CFLAGS) $^ $(LIBFLAG) $(LUA_LIBS)
