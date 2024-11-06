# Phony targets (for organization)
.PHONY: build clean test deploy install

install:
	@echo "Installing dependencies..."
	yarn

# Compilation of contracts
build:
	@echo "Compiling contracts..."
	forge build

# Clean compiled artifacts
clean:
	@echo "Cleaning up..."
	forge clean

##################################################################################
##################################  DEPLOYMENT  ##################################
##################################################################################



########################################## CORE DEPLOYMENTS ##########################################
deploy-vault:
	@echo "Deploying Vault contract on $(NETWORK)..."
	forge script script/deployment/DeployVault.s.sol --rpc-url $(NETWORK) --with-gas-price 600 --broadcast --verify --optimize

deploy-tokens:
	@echo "Deploying Tokens contract on $(NETWORK)..."
	forge script script/deployment/DeployTokens.s.sol --rpc-url $(NETWORK) --broadcast --verify --optimize

deploy-pool:
	@echo "Deploying Pool on $(NETWORK)..."
	forge script script/deployment/DeployWeightPool.s.sol --rpc-url $(NETWORK) --broadcast --verify --optimize
############################################################################################################