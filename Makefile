PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SHAREDIR ?= $(PREFIX)/share

SCRIPTS := bin/cfa install.sh test/fixtures/bin/cloudflared test/fixtures/bin/wrangler test/fixtures/mkcert.sh test/test_helper.bash

.PHONY: help test lint check install uninstall completions

help: ## Show targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

test: ## Run the bats test suite
	bats test

lint: ## Run shellcheck
	shellcheck $(SCRIPTS)

check: lint test ## Lint and test

install: ## Install cfa and shell completions under PREFIX
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 bin/cfa "$(DESTDIR)$(BINDIR)/cfa"
	install -d "$(DESTDIR)$(SHAREDIR)/bash-completion/completions" \
	           "$(DESTDIR)$(SHAREDIR)/zsh/site-functions" \
	           "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d"
	bin/cfa completion bash > "$(DESTDIR)$(SHAREDIR)/bash-completion/completions/cfa"
	bin/cfa completion zsh  > "$(DESTDIR)$(SHAREDIR)/zsh/site-functions/_cfa"
	bin/cfa completion fish > "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d/cfa.fish"

uninstall: ## Remove what `make install` installed
	rm -f "$(DESTDIR)$(BINDIR)/cfa" \
	      "$(DESTDIR)$(SHAREDIR)/bash-completion/completions/cfa" \
	      "$(DESTDIR)$(SHAREDIR)/zsh/site-functions/_cfa" \
	      "$(DESTDIR)$(SHAREDIR)/fish/vendor_completions.d/cfa.fish"
