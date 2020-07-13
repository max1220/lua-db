## Development Installation

You can install symlinks instead of running `make install`.
This makes testing changes easier, as there is no need for `make install`, which
often requires sudo.

```
# make sure target path exists
sudo mkdir -p /usr/local/share/lua/5.1/
sudo mkdir -p /usr/local/lib/lua/5.1/

# install symlinks so make install is not needed after each change
# (adjust paths of lua-db source path)
sudo ln -s $(pwd)/lua /usr/local/share/lua/5.1/lua-db
sudo ln -s $(pwd)/src/ldb_core.so /usr/local/lib/lua/5.1/
sudo ln -s $(pwd)/src/ldb_fb.so /usr/local/lib/lua/5.1/
sudo ln -s $(pwd)/src/ldb_gfx.so /usr/local/lib/lua/5.1/
sudo ln -s $(pwd)/src/ldb_sdl.so /usr/local/lib/lua/5.1/
```
