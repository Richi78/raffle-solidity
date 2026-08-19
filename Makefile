include .env
.PHONY: build clean test coverage test-fork script

build:
	forge build

test:
	forge test

clean:
	forge clean

coverage:
	forge coverage

test-fork:
	forge test --rpc-url $(SEPOLIA_RPC_URL)

script-anvil:
	cast rpc evm_mine --rpc-url $(ANVIL_RPC_URL)
	cast block-number --rpc-url $(ANVIL_RPC_URL)

# 	forge script script/Interactions.s.sol \
# 		--target-contract CreateSubscription \
# 		--rpc-url $(ANVIL_RPC_URL) \
# 		--private-key $(ANVIL_PRIVATE_KEY) \
# 		--broadcast
	forge script script/DeployRaffle.s.sol \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast \
  	 	-vvvv
# 	forge script script/Interactions.s.sol \
# 		--target-contract AddConsumer \
# 		--rpc-url $(ANVIL_RPC_URL) \
# 		--private-key $(ANVIL_PRIVATE_KEY) \
# 		--broadcast