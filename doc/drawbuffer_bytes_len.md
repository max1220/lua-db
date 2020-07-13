## drawbuffer:bytes_len()

Returns the size of the memory allocated for the drawbuffer data in bytes.
It's always `(drawbuffer:width() * drawbuffer:height() * bpp) / 8`.

returns the byte lenght of the drawbuffer on success, nil otherwise(closed)
