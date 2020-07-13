## Examples

There are a bunch of examples in the `examples/` folder.
They should be run from the main directory to find the assets, if any.

They all share common output and input options
(defined by `ldb.input_output.new_from_args`).

e.g. if there is a X11 server running:
```
./examples/clock.lua --sdl --width=320 --height=240
```

on a unicode terminal:
```
./examples/clock.lua --halfblocks
```

The examples might leave your terminal emulator in a bad state, you might need
to run `reset`.

Here are a few screenshots of the running examples:

TODO: Add screenshots
