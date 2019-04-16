ldb - lua drawbuffers
----------------------

This project is a continuation of lfb, the lua framebuffer library.
(Or at least the graphics buffer part of it)

See the lfb readme for docu.

This project was seperated because it could be usefull outside the framebuffer context.

Additional tools, for example for reading/writing .bmp, .ppm, .pgm, .pbm files into drawbuffers will also be put here.

The framebuffer part of the lfb project will soon be implemented as a seperate c module with interoperabillity with this library.

Due to now having a shared metatable, the width and height can no longer be stored in the metatable as integers.
Instead, call the db:width() and db:height() functions

This repository also contains a few usefull pure-lua libraries for handling graphics. (Some of them can be used without ldb)

The seperate modules can be loaded individually, or together. For loading them together, just call require("lua-db").
If you want to load them individually, use require("lua-db.module_name"), where module_name is the name of the module
you want to load. The C part of the module is loaded using require("lua-db.lua_db"). Some of the Lua modules require this
module.

Here is some basic documentation on these modules





lua-db
-------

The main module, contains functions for handling drawbuffers. When loading this module, the other submodules are automatically loaded
into the same table(e.g require("lua-db").bitmap ).


Actually only exports the new function:

	ldb.new(width, height) --> drawbuffer



Each drawbuffer supports the following functions:



	db:width() --> width

	db:height() --> height

Gets the dimensions of this drawbuffer.



	db:get_pixel(x,y) --> r,g,b,a

	db:get_pixel(x,y,r,g,b,a)

Gets or sets the pixel at x,y to r,g,b,a(0-255)



	db:set_rectangle(x,y,w,h,r,g,b,a)

Fills the rectangle defined by x,y,w,h with the color r,g,b,a(0-255)



	db:set_box(x,y,w,h,r,g,b,a)

Fills the outline of the rectangle defined by x,y,w,h with the color r,g,b,a(0-255)



	db:set_line(x0,y0,x1,y1,r,g,b,a)

Draws a line from x0,y0 to x1,y1 in the color r,g,b,a(0-255). Not aliased.



	db:clear(r,g,b,a)

Clears the contens of the drawbuffer, leaving the entire drawbuffer filled with r,g,b,a(0-255)



	db:draw_to_drawbuffer(target_db, target_x, target_y, origin_x, origin_y, width, height, scale)

Copy the content from db to target_db. target_x,target_y is the coordinate in the image that is beeing copied into.
origin_x, origin_y is the coordinate from the source draw buffer. Width and height define how large a rectangle is
copied from the source. if scale is > 1, then the image is drawn scaled to the target_db.



	db:pixel_function(pixel_callback)
	pixel_callback(x,y,r,g,b,a) --> r,g,b,a

Calls the pixel_callback function for each pixel in the drawbuffer, setting the pixel to the returned value.
Kind of slow due to Lua call overhead; Only use while loading/not during main game.



	db:dump_data() --> data

Get the data from the drawbuffer as string(4byte r-g-b-a, left-to-right, top-to-bottom).



	db:bytes_len() --> len

returns the ammount of data dump_data would return(mostlye width*height*4)



	db:load_data(data)

Loads the the string data as pixel_data. Reverse of dump_data(). 



	db:close()

Close the drawbuffer, freeing memory





ppm.lua - input/output as portable pixmap(.ppm)
-----------------------------------------

Reads and writes portable pixmap(.ppm) graphics files.

	ppm.decode_from_string_pixel_callback(str, pixel_callback) --> width, height
	pixel_callback(x,y,r,g,b)

Decodes a .ppm from a string, calling pixel_callback for each pixel.



	ppm.decode_from_string_drawbuffer(str) --> drawbuffer

Decodes a .ppm from a string into a new drawbuffer.



	ppm.decode_from_file_drawbuffer(filepath) --> drawbuffer

Decodes the .ppm file filepath into a new drawbuffer.



	ppm.encode_from_pixel_callback(width, height, pixel_callback) --> str
	pixel_callback(x,y) --> r,g,b

Encode a new .ppm image by calling pixel_callback for each pixel in width*height.



	ppm.encode_from_drawbuffer(db) --> str

Encodes a new .ppm image from a drawbuffer.





term.lua - handle terminal escape sequences
--------------------------------------------

utillities for working with terminal esacape sequences(Mostly ANSI).
They don't write the codes directly to the terminal, instead they return
the code as string.



	term.set_cursor(x, y)  --> ansi

Sets the current cursor position in the terminal. Starts at 0,0ds



	term.get_screen_size() -->w,h

gets the terminal screen size. Uses tput if aviable, bash variables otherwise



	term.clear_screen() --> ansi

clears the screen and resets cursor position to 0,0



	term.reset_color() --> ansi

Resets the SGR parameters(foreground/background  color)



	term.rgb_to_ansi_color_fg_24bpp(r, g, b) --> ansi

Convert the r,g,b(0-255) values to an ANSI escape sequence for setting the foreground color in 24-bit-color space



	term.rgb_to_ansi_color_bg_24bpp(r, g, b) --> ansi

Convert the r,g,b(0-255) values to an ANSI escape sequence for setting the background color in 24-bit-color space



	term.rgb_to_ansi_color_fg_216(r, g, b) --> ansi

Convert the r,g,b(0-255) values to an ANSI escape sequence for setting the foreground color in 216-color space



	term.rgb_to_ansi_color_bg_216(r, g, b) --> ansi

Convert the r,g,b(0-255) values to an ANSI escape sequence for setting the background color in 216-color space





blocks.lua - draw on the screen by using empty terminal cells
--------------------------------------------------------------

This library draws on the screen by outputting a colored space character
for each pixel.



	draw_pixel_callback(width, height, pixel_callback) --> lines
	pixel_callback(x, y) --> r,g,b

Draw by calling a pixel callback with the coordinates for each pixel.
The pixel callback takes x,y coordinates and should return r,g,b (0-255)
values. The returned table lines contains the generated lines, and
can be turned into a string by using table.concat(lines, term.reset_color .. "\n").



	draw_db(db) --> lines

Draws from a drawbuffer. Same as above. Internally calls draw_pixel_callback





Braile.lua - draw on the screen by using unicode braile characters
-------------------------------------------------------------------

This library converts pixels into a sequence of utf8 braile characters,
for displaying higher-resolution graphics on terminal emulators.

It features 3 functions to turn pixel data into braile characters.
All of them return a list of lines, and use the draw_pixel_callback
function internally.



	Braile.draw_pixel_callback(width, height, pixel_callback, color_callback)
	pixel_callback(x,y) --> 1 if pixel is set, 0 otherwise
	color_callback(x,y) --> ANSI color code(string)

Calls the pixel_callback for each pixel in the specified dimensions to
set the braile character bits for each character. pixel_callback is
called with the coordinates for each pixel, and should return 1 if the
pixel is set, 0 otherwise.

If color_callback if set, also calls color_callback for each character
generated with the coordinates of the top-left pixel of that character.
color_callback should return a ANSI escape sequence that sets the
foreground/background color of the terminal to the color of the pixel.
The color codes can be generated by the term.lua module.



	Braile.draw_db(db, threshold, color)

Converts the lua-db drawbuffer to a braile character sequence.
A pixel is considered set if the average of the r,g,b values is above
the specified threshold. If colors is true, the output will also be
colored as described above.



	Braile.draw_table(tbl, bpp24)

Iterates over the table tbl to draw an image in braile characters.
The width drawn is either the lenght of the first line or
tbl.width(if present), and the height the ammount of lines or
tbl.height. The table can be arbitrarily sparse, pixels not present in
the table are considered not set. bpp_24 enables the 24-bit color output.

tbl should contain a list of lines so that each line contains a list of
pixel/color values, so that you could get the pixel information by:

	local px, r, g, b = unpack(tbl[y][x])

If the r,g,b values are present, the character at that position will be 
colored.





bitmap.lua - read/write windows bitmaps(24bpp only)
----------------------------------------------------

Pure lua library for reading/writing windows bitmaps(.bmp).
Only supports 24 bits per pixel encoding, and no compression, or stride,
etc.



	Bitmap.generate_header(width, height)

Returns a header(string) for a 24bpp bitmap with no compression etc.,
for the specified dimensions. The pixel data should start immediatly
after the generated header, but is not generated by this function.



	Bitmap.decode_header(str)

Reads the bitmap file content in str, and returns a table that contains
the following values from the header: width, height, data_size, data_offset



	Bitmap.decode_from_string_pixel_callback(str, pixel_callback)
	pixel_callback(x,y,r,g,b)

Reads the bitmap file content in str, parses the header, and calls
pixel_callback with the x,y coordinates and r,g,b values(0-255)



	Bitmap.decode_from_string_drawbuffer(str)

Reads the bitmap file content in str, parses the header, and returns a
drawbuffer that contains the pixel data from the bitmap



	Bitmap.decode_from_file_drawbuffer(filepath)

Return a drawbuffer with the image loaded from filepath



	Bitmap.encode_from_pixel_callback(width, height, pixel_callback)
	pixel_callback(x,y) --> r,g,b

Encode(generate) a bitmap based on a width, height and a pixel_callback.
The pixel_callback is called for each pixel in the specified region and
should return the r,g,b(0-255). The bitmap is returned as a string, and
can be written to a file.



	Bitmap.encode_from_drawbuffer(db)

Encode(generate) a bitmap from a drawbuffer. The bitmap is returned as a
string, and can be written to a file.





font.lua - simple bitmap fonts
-------------------------------

A library to handle simple bitmap fonts stored in drawbuffers.
The bitmap fonts must have fixed dimensions per character, and should
not have any borders around the characters. Each character is copied to
the drawbuffer as-is, but if alpha is 0 in the source drawbuffer, the
corresponding pixels in the target drawbuffers will not be touched.
The characters are identified by their char_id. The char_id starts at 0
for the first character in the top-left corner, and increases for each
character(left to right, top to bottom). Some functions interprete strings
as a sequence of 1-byte char_ids, so it's easiest to have the image
aranged so that the relevant char_id regions produce sensible output.
alpha_color is a the {r, g, b} that sets the transparency color. All
other colors are untouched. This is usefull in combination with from_file,
because it loads a bitmap without alpha support.


This library only exports two function:



	Font.from_drawbuffer(db, char_w, char_h, alpha_color, scale) --> font(see below)
	Font.from_file(filepath, char_w, char_h, alpha_color, scale) --> font(see below)

Return a font table that contains a parsed version of the font, and
functions for drawing to other drawbuffers.
Each font has the following functions:



	font:draw_character(target_db, char_id, x, y)

Draws the single character identified by it's char_id to target_db at x,y.



	font:draw_string(target_db, str, x, y, max_width)

Draws the string str to target_db at x,y. The string is converted to
bytes that are used as char_ids.



	font:string_size(str, max_width) --> width, height

Gets the rendered dimensions of the string using the specified max_width.





Examples
---------

	./example_drawing.lua

Draws basic geometry on a drawbuffer, then outputs using blocks.lua.



	./example_bitmap.lua img.bmp

This is basically a terminal .bmp viewer(Using unicode braile-characters)



	echo "Hello World!" | ./example_font.lua cga8.bmp 8 8 [outfile.bmp]

Render the string from stdin in the supplied 8x8 font. If outfile is
specified, the output is also written as a bitmap to it.



	./example_ffmpeg.lua /dev/video0 640 480 [mode] [24bpp]

A webcam viewer for the terminal! Could also be easily adapted to be
a terminal video player. Can output to: a terminal(using braile.lua or
blocks.lua), to the linux framebuffer, or a SDL2 window. Reads from
ffmpeg's stdout, so requires ffmpeg in $PATH. Mode specifies the output
mode, and can be one of: lfb, sdl2fb, braile, block.
For braile and block, also specifing 24bpp enables 24-bit ANSI escape
sequences for more accurate colors. 





TODO
-----

 - documentation in seperate files, wiki
 - screenshots for github
 - web output via http multipart + svg/bmp
 - ffmpeg
   - documentation
   - sound?
   - use unix socket for data, stdin for control
 - sdl2fb
   - document 
 - lua-vnc
   - test/document 
 - bitmap
   - support 32bpp encoding(directly from drawbuffer, via db:dump_data(), add correct bitmask
 - document
   - sox.lua
   - example_sox
   - imlib
   - tileset
   - raw


write tests
