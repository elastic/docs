include ../common.mk

.PHONY: check
check: jest

.PHONY: jest
jest:
	$(DOCKER) integ_test /node_modules/jest/bin/jest.js ./__test__/**
