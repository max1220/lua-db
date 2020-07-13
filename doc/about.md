# lua-db - lua drawbuffers

This is a Lua library for graphics programming, written in C and Lua.
It's main component is a drawbuffer, a buffer that has a width, height,
pixel format, and pixel data. There are various graphics primitives
available for the drawbuffer objects, e.g. lines, triangles, rectangles.
lua-db does not support any hardware acceleration.

There are multiple output options:
 * SDL window
 * Linux framebuffer
 * Terminal output
   - monochrome/8bit colors/24bit colors
   - braile characters(required utf8 support, only 1 color per 2x4 pixels)
   - block characters(required utf8 support)
   - regular characters
