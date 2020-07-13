## local r,g,b,a = drawbuffer:get_px(x,y)

This function returns the color of a single pixel on the drawbuffer.


`x` is in range 0 -> db:width()-1

`y` is in range 0 -> db:height()-1

returns `r,g,b,a` in range 0-255 on success, nil otherwise
