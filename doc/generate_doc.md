## generate_doc.lua

This script merges a document tree definition with it's content for export.

Usage:

```
./generate_doc.lua tree [output] [--merge/--plain/--html_anchor/--html_link] [--help]
```

`tree` is the file path to a document tree in JSON or Lua format.
`output` is the optional output file path(Default is stdout)
`--merge` only merges the content(no menu, no anchors, default)
`--plain` exports a merged pure markdown document with an unclickable menu(no HTML)
`--html_anchor` exports markdown with HTML for local page anchors and a clickable HTML menu
`--html_menu` only exports menu markdown with external links(no content)
`--help` prints this message


The documentation is split into two parts:
 * The content(Markdown)
 * A document tree(Lua/JSON) describing the structure of the documentation.

This script reads a document tree from a file, then generates output based on
that document tree. It supports:
 * merge the content files into a "flat" representation
 * auto-generate a (HTML-)menu and HTML anchors between sections.

It does not convert Markdown to HTML, instead it only merges HTML snippets into
a combined markdown document.

A document tree is a list of document entries. Each entry supports the following
fields:

 * `title` - Menu title for this entry(leave blank for no menu entry/anchor)
 * `file` - filepath for the referenced document
 * `children` - list of other documents that are "children" to this document

Example document tree:

```
return {
	{
		title = "About",
		file = "about.md",
	},
	{
		title = "Installation",
		file = "installation.md",
		children = {
			{
				title = "Dependencies",
				file = "dependencies.md",
			}
		}
	}
}
```

In the "flattened" version, parents come before their children(In this example,
the content of `installation.md` would come before `dependencies.md`).
