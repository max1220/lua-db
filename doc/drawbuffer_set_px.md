## drawbuffer:set_px(x,y,r,g,b,a)

This function set a single pixel on the drawbuffer.
No blending is performed, see `:set_px_alphablend` for that.


`r,g,b,a` is the color, in range 0-255

`x` is the x axis position in range 0 -> db:width()-1

`y` is the y axis position in range 0 -> db:height()-1

returns true on success, nil otherwise
