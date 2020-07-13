## drawbuffer:dump_data()

This function returns the internal representation of the pixel data as a Lua
string.

The format of pixel data in this string depends on the drawbuffer pixel format.
It's length is always `drawbuffer:bytes_len()`. It does not contains any header
etc.

returns pixel data as a string on success, nil otherwise(closed)
