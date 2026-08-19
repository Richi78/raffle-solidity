include .env
.PHONY: build clean test coverage test-fork  coverage-report

build:
	forge build

test:
	forge test

clean:
	forge clean

coverage:
	forge coverage

coverage-report:
	forge coverage --report debug > coverage.txt

test-fork:
	forge test --fork-url $(SEPOLIA_RPC_URL)
