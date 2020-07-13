## drawbuffer:close()

Frees up the memory taken by the pixel data of the drawbuffer.

This invalidates all drawbuffer related functions for this drawbuffer except
`drawbuffer:tostring()`.

You do not need to call this function manually, this is set for the `__gc`
meta-method on all drawbuffers, so Lua can clean up all memory automatically on
garbage collection once all references are gone.

always returns true.
