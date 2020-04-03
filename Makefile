


# Install/Uninstall configuration
PREFIX = /usr/local
LUA_DIR = $(PREFIX)
LUA_LIBDIR = $(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR = $(LUA_DIR)/share/lua/5.1

.PHONY: all
all: build doc
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

.PHONY: clean
clean:
	make -C src/ clean
	make -C doc/ clean

.PHONY: todo
todo:
	rgrep --color -i -H -n -T "TODO"

.PHONY: install
install: build
	@echo "-> Installing in $(PREFIX)"
	install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_core.so
	install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_gfx.so
	install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_sdl.so
	install -b -m 644 -t $(LUA_LIBDIR)/ src/ldb_fb.so
	install -b -d $(LUA_SHAREDIR)/lua-db
	install -b -d $(LUA_SHAREDIR)/lua-db/gui
	install -b -t $(LUA_SHAREDIR)/lua-db lua/*.lua
	install -b -t $(LUA_SHAREDIR)/lua-db/gui lua/gui/*.lua


.PHONY: uninstall
uninstall:
	@echo "-> Uninstalling from $(PREFIX)"
	rm -f $(LUA_LIBDIR)/ldb_core.so
	rm -f $(LUA_LIBDIR)/ldb_gfx.so
	rm -f $(LUA_LIBDIR)/ldb_sdl.so
	rm -f $(LUA_LIBDIR)/ldb_fb.so
	rm -r -f $(LUA_SHAREDIR)/lua-db
