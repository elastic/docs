# We expect this to be run in the a docker container managed by
#   build_docs --self-test

SHELL = /bin/bash -eux -o pipefail
MAKEFLAGS += --silent

.PHONY: check
check: rspec rubocop

.PHONY: rspec
rspec:
	rspec spec/copy_images_spec.rb

.PHONY: rubocop
rubocop:
	rubocop
