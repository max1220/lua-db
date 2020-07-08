LUA=lua5.1
src := $(sort $(wildcard test_*.lua))

.PHONY: all
all: test
	@echo "Running all tests."

.PHONY: help
help:
	@echo "Supported make targets:"
	@echo " test (run the test cases)"

.PHONY: $(src)
$(src):
	@echo "Running test" $@
	$(LUA) $@

.PHONY: test
test: $(src)
