CFLAGS = -O3 -fPIC -I/usr/include/lua5.1 -Wall -Wextra
LIBS   = -shared -llua5.1 -lm
TARGET = lua_db.so

all: $(TARGET)

$(TARGET): lua-db.c lua-db.h
	$(CC) -o $(TARGET) lua-db.c $(CFLAGS) $(LIBS)
	# $(CC) -o $(TARGET) lua-db.c $(CFLAGS) $(LIBS)
	strip $(TARGET)

clean:
	rm -f $(TARGET)
