# Install/Uninstall configuration
PREFIX ?= /usr/local
LUA_LIBDIR ?= $(PREFIX)/lib/lua/5.1
LUA_SHAREDIR ?= $(PREFIX)/share/lua/5.1

.PHONY: all
all: build doc test
	@echo "-> Building finished."

.PHONY: help
help:
	@echo "Available make targets: help(this message)"
	@echo " build(build the library)"
	@echo " doc(Build documentation)"
	@echo " clean(remove build and doc artifacts)"
	@echo " install(install build files)"
	@echo " uninstall(remove installed files)"
	@echo "You can controll more aspects of the library build if you run make in the src/ directory(run make -C src/ help)."

.PHONY: build
build:
	make -C src/ all

.PHONY: doc
doc:
	make -C doc/ all

.PHONY: test
test:
	make -C tests/ all

.PHONY: clean
clean:
	make -C src/ clean
	make -C doc/ clean

.PHONY: todo
todo:
	rgrep --color -i -H -n -T "TODO"

.PHONY: install
install: src/ldb_core.so
	@echo "-> Installing in $(LUA_LIBDIR) and $(LUA_SHAREDIR)"
	mkdir -p $(LUA_LIBDIR)/
	install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_core.so
	test -f src/ldb_gfx.so && install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_gfx.so || true
	test -f src/ldb_sdl.so && install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_sdl.so || true
	test -f src/ldb_fb.so && install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_fb.so || true
	test -f src/ldb_drm.so && install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_drm.so || true
	mkdir -p $(LUA_SHAREDIR)/
	install -b -d $(LUA_SHAREDIR)/lua-db
	install -b -d $(LUA_SHAREDIR)/lua-db/gui
	install -b -t $(LUA_SHAREDIR)/lua-db lua/*.lua
	install -b -t $(LUA_SHAREDIR)/lua-db/gui lua/gui/*.lua


.PHONY: uninstall
uninstall:
	@echo "-> Uninstalling from $(LUA_LIBDIR) and $(LUA_SHAREDIR)"
	rm -f $(LUA_LIBDIR)/ldb_core.so
	rm -f $(LUA_LIBDIR)/ldb_gfx.so
	rm -f $(LUA_LIBDIR)/ldb_sdl.so
	rm -f $(LUA_LIBDIR)/ldb_fb.so
	rm -r -f $(LUA_SHAREDIR)/lua-db
