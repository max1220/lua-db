MD=cmark
src := $(sort $(wildcard *.md))
anchors_src := $(src:.md=._md)
all_src = $(src) $(anchors_src)
all_sort_src = $(sort $(all_src))


.PHONY: all
all: md html
	@echo "Building doc finished."

.PHONY: help
help:
	@echo "Supported make targets:"
	@echo " help (this message)"
	@echo " md (generate markdown documentation)"
	@echo " html (generate HTML documentation)"
	@echo " clean (clean up markdown and HTML artifacts)"


$(anchors_src):
	./generate_anchor.lua $@ > $@

index._md: $(src)
	./generate_index_md.lua $^ > $@

merged._md: index._md $(all_sort_src)
	cmark -t commonmark $^ > $@

merged.html: merged._md
	cmark -t html --unsafe $^ > $@


.PHONY: md
md: merged._md

.PHONY: html
html: merged.html


.PHONY: clean
clean:
	rm -f merged.html *._md
