CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic
#CFLAGS = -O3 -fPIC -std=c99 -Wall -Wextra -Wpedantic -march=native -mtune=native
LIBS   = -shared -lm
TARGET = lua_db.so

# by default, build for lua5.1, because it has ABI compabillity with luajit
LUA_CFLAGS = -I/usr/include/lua5.1
LUA_LIBS = -llua5.1

# we can also build for lua5.3
ifdef lua53
	LUA_CFLAGS = -I/usr/include/lua5.3
	LUA_LIBS = -llua5.3
endif


all: $(TARGET)

$(TARGET): lua-db.c lua-db.h
	$(CC) -o $(TARGET) lua-db.c $(CFLAGS) $(LUA_CFLAGS) $(LIBS) $(LUA_LIBS)
	strip $(TARGET)


clean:
	rm -f $(TARGET)
