NVIM ?= nvim

.PHONY: test
test:
	XDG_DATA_HOME=$$(mktemp -d /tmp/codereview-test-data.XXXXXX) \
	XDG_STATE_HOME=$$(mktemp -d /tmp/codereview-test-state.XXXXXX) \
	XDG_CACHE_HOME=$$(mktemp -d /tmp/codereview-test-cache.XXXXXX) \
	$(NVIM) --headless -u tests/minimal_init.lua -c 'lua require("tests.run").run()' -c 'qa'
