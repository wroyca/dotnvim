.PHONY: test doc clean all check-updates update-mini-doc update-mini-test

all: check-updates test doc

test:
	@echo "Running tests with mini.test..."
	@nvim --headless \
		-c "lua vim.opt.runtimepath:append('.')" \
		-c "lua vim.opt.runtimepath:append('./pack/dist/opt/mini.test')" \
		-c "lua require('mini.test').run()" \
		-c "quitall"

doc:
	@echo "Generating documentation with mini.doc..."
	@nvim --headless \
		-c "lua vim.opt.runtimepath:append('.')" \
		-c "lua vim.opt.runtimepath:append('./pack/dist/opt/mini.doc')" \
		-c "lua require('mini.doc').generate()" \
		-c "quitall"

clean:
	@echo "Cleaning generated files..."
	@rm -f doc/*.txt
	@echo "Done!"

help:
	@echo "Available targets:"
	@echo "  all           - Run test and doc (default)"
	@echo "  test          - Run tests using mini.test"
	@echo "  doc           - Generate documentation using mini.doc"
	@echo "  clean         - Clean generated files"
	@echo "  check-updates - Update mini.doc and mini.test"
	@echo "  help          - Show this help message"

check-updates:
	@echo "checking for updates..."
	@$(MAKE) --silent check-mini-doc-version
	@$(MAKE) --silent check-mini-test-version

check-mini-doc-version:
	@current_version=$$(cat pack/dist/opt/mini.doc/VERSION 2>/dev/null || echo "unknown"); \
	latest_version=$$(curl -s https://api.github.com/repos/echasnovski/mini.doc/tags | jq -r '.[0].name' 2>/dev/null || echo "unknown"); \
	if [ "$$current_version" != "$$latest_version" ] && [ "$$latest_version" != "unknown" ]; then \
		echo "mini.doc update available: $$current_version -> $$latest_version"; \
		$(MAKE) update-mini-doc LATEST_VERSION=$$latest_version; \
	else \
		echo "mini.doc is up to date ($$current_version)"; \
	fi

check-mini-test-version:
	@current_version=$$(cat pack/dist/opt/mini.test/VERSION 2>/dev/null || echo "unknown"); \
	latest_version=$$(curl -s https://api.github.com/repos/echasnovski/mini.test/tags | jq -r '.[0].name' 2>/dev/null || echo "unknown"); \
	if [ "$$current_version" != "$$latest_version" ] && [ "$$latest_version" != "unknown" ]; then \
		echo "mini.test update available: $$current_version -> $$latest_version"; \
		$(MAKE) update-mini-test LATEST_VERSION=$$latest_version; \
	else \
		echo "mini.test is up to date ($$current_version)"; \
	fi

update-mini-doc:
	@if [ -z "$(LATEST_VERSION)" ]; then \
		echo "error: LATEST_VERSION not specified"; \
		exit 1; \
	fi
	@echo "updating mini.doc to $(LATEST_VERSION)..."
	@rm -rf pack/dist/opt/mini.doc.tmp
	@curl -sL https://github.com/echasnovski/mini.doc/archive/refs/tags/$(LATEST_VERSION).tar.gz | tar xz -C pack/dist/opt/
	@mv pack/dist/opt/mini.doc-* pack/dist/opt/mini.doc.tmp
	@rm -rf pack/dist/opt/mini.doc
	@mv pack/dist/opt/mini.doc.tmp pack/dist/opt/mini.doc
	@echo "$(LATEST_VERSION)" > pack/dist/opt/mini.doc/VERSION

update-mini-test:
	@if [ -z "$(LATEST_VERSION)" ]; then \
		echo "Error: LATEST_VERSION not specified"; \
		exit 1; \
	fi
	@echo "updating mini.test to $(LATEST_VERSION)..."
	@rm -rf pack/dist/opt/mini.test.tmp
	@curl -sL https://github.com/echasnovski/mini.test/archive/refs/tags/$(LATEST_VERSION).tar.gz | tar xz -C pack/dist/opt/
	@mv pack/dist/opt/mini.test-* pack/dist/opt/mini.test.tmp
	@rm -rf pack/dist/opt/mini.test
	@mv pack/dist/opt/mini.test.tmp pack/dist/opt/mini.test
	@echo "$(LATEST_VERSION)" > pack/dist/opt/mini.test/VERSION
