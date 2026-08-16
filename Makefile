include .env
.PHONY: build clean test coverage

build:
	forge build

test:
	forge test

clean:
	forge clean

coverage:
	forge coverage