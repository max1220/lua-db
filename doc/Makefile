MD=cmark
DOCTREE=document_tree.lua
MD_MERGED=merged.md
HTML_INDEX=index.html
HTML_MERGED=merged.html
TMP_HTML_MERGE=merged.html.md

$(MD_MERGED): $(DOCTREE)
	./generate_doc.lua --merge $^ $@

$(HTML_MERGED): $(TMP_HTML_MERGE)
	cmark -t html --unsafe $^ > $@

$(TMP_HTML_MERGE): $(DOCTREE)
	./generate_doc.lua --html_anchor $^ $@

$(HTML_INDEX): $(DOCTREE)
	./generate_doc.lua --html_menu $^ $@


.PHONY: help
help:
	@echo "Supported make targets:"
	@echo " help (this message)"
	@echo " all (generate documentation in all formats)"
	@echo " index (generate documentation index)"
	@echo " md (generate merged markdown documentation)"
	@echo " html (generate HTML documentation)"
	@echo " clean (clean up markdown and HTML artifacts)"


.PHONY: md
md: $(MD_MERGED)

.PHONY: index
index: $(HTML_INDEX)

.PHONY: html
html: $(HTML_MERGED)


.PHONY: all
all: index md html
	@echo "Building doc finished."


.PHONY: clean
clean:
	rm -f $(MD_MERGED) $(HTML_INDEX) $(TMP_HTML_MERGE) $(HTML_MERGED)
