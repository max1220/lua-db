MD=cmark
src := $(sort $(wildcard *.md))
anchors_src := $(src:.md=.anchor_md)
all_src = $(src) $(anchors_src)
sort_src = $(sort $(all_src))


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

.PHONY: anchors
anchors: $(src)
	./generate_anchors.lua $^

$(anchors_src):

merged._md: index._md $(sort_src)
	cmark -t commonmark $^ > $@

merged.html: merged._md
	cmark -t html --unsafe $^ > $@

index._md: $(src)
	./generate_index_md.lua $^ > $@

.PHONY: md
md: anchors index._md merged._md

.PHONY: html
html: anchors md *.md merged.html


.PHONY: clean
clean:
	rm -f merged.html index._md merged._md *.anchor_md
