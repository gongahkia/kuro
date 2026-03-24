LUA ?= lua
LOVE ?= love

.PHONY: run test lint

run:
	@if command -v $(LOVE) >/dev/null 2>&1; then \
		$(LOVE) .; \
	else \
		printf "Love 11.x is not installed. Run: love .\n"; \
	fi

test:
	@$(LUA) tests/run.lua

lint:
	@$(LUA) -e 'assert(loadfile("main.lua"))'
