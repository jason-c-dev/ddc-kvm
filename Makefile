# ddc-kvm - development targets
#
#   make test      run the bats test suite
#   make lint      shellcheck every script
#   make validate  validate the Claude Code plugin manifest (needs the claude CLI)
#   make install   symlink scripts/ddc-kvm into ~/.local/bin
#   make uninstall remove that symlink

PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
BATS    ?= bats
SHELLCHECK ?= shellcheck

SCRIPTS := scripts/ddc-kvm tests/fakes/* tests/test_helper.bash

.PHONY: test lint validate install uninstall check

check: lint test

test:
	$(BATS) tests

lint:
	$(SHELLCHECK) -x $(SCRIPTS)

validate:
	claude plugin validate --strict .

install:
	mkdir -p $(BINDIR)
	ln -sf $(CURDIR)/scripts/ddc-kvm $(BINDIR)/ddc-kvm
	@echo "installed $(BINDIR)/ddc-kvm -> $(CURDIR)/scripts/ddc-kvm"

uninstall:
	rm -f $(BINDIR)/ddc-kvm
