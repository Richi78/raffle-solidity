include .env
.PHONY: build clean test coverage test-fork  coverage-report help deploy install

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

help:
	@echo "Useage: " 
	@echo " make deploy [ARGS=...]"

install:
	forge install Cyfrin/foundry-devops --no-git
	forge install smartcontractkit/chainlink-evm --no-git
	forge install OpenZeppelin/openzeppelin-contracts --no-git
	forge install foundry-rs/forge-std --no-git

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

#####################################################

NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast --skip-simulation --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# if --network sepolia is uset, then use sepolia stuff, otherwise anvil stuff
ifeq ($(findstring --network sepolia, $(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --skip-simulation --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy: 
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

#####################################################