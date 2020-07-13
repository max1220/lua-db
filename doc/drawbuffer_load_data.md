## drawbuffer:load_data(data)

This function loads the entire drawbuffer content from a Lua string(replaces
all pixel data).

The lenght of this string must be the same as `drawbuffer:bytes_len()`

The format is the same as `drawbuffer:load_data(data)` would return, and
depends on the drawbuffer pixel format

returns true on success, nil otherwise
