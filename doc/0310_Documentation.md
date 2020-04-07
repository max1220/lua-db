## Building Documentation

The Documentation is located in doc/ in markdown format.

You can run "make doc" to generate the merged documentation in HTML and markdown.
This will also generate the index and anchor files.

This requires the `cmark` markdown converter to be installed and callable.

The merged output files will be in `doc/merged._md` and `doc/merged.html`.

This repository might contain a `doc/merged._md` and `doc/merged.html` for
convenience, but this might be out of date at times.
