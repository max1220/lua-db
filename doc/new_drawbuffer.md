## ldb_core:new_drawbuffer(w,h,px_fmt)

The purpose of this function is to create a new
drawbuffer(A structure to hold and manipulate pixels), with the specified
width, height and pixel_format. On success, it returns the new drawbuffer, on
failure it returns nil, plus an error message.

The first two arguments are width and height, and should be an integer larger
than 0.

The last argument defines the pixel format used to represent the pixel data
internally. It is also an integer, and should be taken from the `pixel_formats`
table. Index this table with one of the following values:
 * `r1`
 * `r8`
 * `rgb332`
 * `rgb565`
 * `bgr565`
 * `rgb888`
 * `bgr888`
 * `rgba8888`
 * `argb8888`
 * `abgr8888`
 * `bgra8888`
