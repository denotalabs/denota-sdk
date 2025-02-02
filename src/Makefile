-include ../.env

FACTORY_ADDRESS=0x0000000000FFe8B47B3e2130213B802212439497
DEPLOY_RPC_URL=${POLYGON_RPC_URL}
VERIFIER_URL=https://api.polygonscan.com/api/  # https://api-sepolia.etherscan.io/api
optimizer_runs=1000000

ADDRESS_LOCAL=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PRIVATE_KEY_LOCAL=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
FACTORY_ADDRESS_LOCAL=0x5FbDB2315678afecb367f032d93F642f64180aa3
DEPLOY_RPC_URL_LOCAL=127.0.0.1:8545

# "brew install jq" if needed
# `anvil` in a separate terminal to run the local chain
# Should get a MIME type string as final output from tokenURI-local
deploy-all-local: deploy-factory-local deploy-token-local deploy-registrar-local deploy-hook-local write-local tokenURI-local

deploy-factory-local:
	forge create src/ImmutableCreate2Factory.sol:ImmutableCreate2Factory \
	--broadcast --optimizer-runs ${optimizer_runs} --private-key ${PRIVATE_KEY_LOCAL} --rpc-url ${DEPLOY_RPC_URL_LOCAL};

deploy-token-local:
	forge create test/mock/MockERC20.sol:MockERC20 --broadcast --private-key ${PRIVATE_KEY_LOCAL} --optimizer-runs ${optimizer_runs} --constructor-args "Dai" "DAI" 18 --rpc-url ${DEPLOY_RPC_URL_LOCAL};

# 0.5hrs for 9 zeros base M1 air
mine-registrar-local:
	constructorArgs=$$(cast abi-encode "constructor(address)" ${ADDRESS_LOCAL}) ; \
	constructorArgs=$$(echo $${constructorArgs} | sed 's/0x//') ; \
	bytecode=$$(jq -r '.bytecode.object' ../out/NotaRegistrar.sol/NotaRegistrar.json)$${constructorArgs} ; \
	cast create2 --deployer ${FACTORY_ADDRESS_LOCAL} --init-code $${bytecode} --starts-with 00000 --caller ${ADDRESS_LOCAL} 2>&1 | tee NotaRegistrar.salt.txt ; \
	echo $$(cat NotaRegistrar.salt.txt | grep "Salt: " | awk '{print $$2}') ;

# Paste this in from the output of the above command if registrar code changes
salt=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266565441984160818b3169ac95
deploy-registrar-local:
	constructorArgs=$$(cast abi-encode "constructor(address)" ${ADDRESS_LOCAL}) ; \
	constructorArgs=$$(echo $${constructorArgs} | sed 's/0x//') ; \
	bytecode=$$(jq -r '.bytecode.object' ../out/NotaRegistrar.sol/NotaRegistrar.json)$${constructorArgs} ; \
	cast send ${FACTORY_ADDRESS_LOCAL} "safeCreate2(bytes32,bytes calldata)" ${salt} $${bytecode} --private-key ${PRIVATE_KEY_LOCAL} -- --broadcast --rpc-url ${DEPLOY_RPC_URL_LOCAL};

# Paste from salt file if registrar code changes
registrarAddress=0x00000F6149D9BEA64faea6b5D7E5255b40c2a2c8
deploy-hook-local:
	forge create --broadcast --private-key ${PRIVATE_KEY_LOCAL} test/mock/MockHook.sol:MockHook --constructor-args ${registrarAddress} --optimizer-runs ${optimizer_runs}--rpc-url ${DEPLOY_RPC_URL_LOCAL}

writeSelector="write(address,uint256,uint256,address,address,bytes)"
currency=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 # deployed token address
escrow=100
instant=0
owner=0x70997970C51812dc3A010C7d01b50e0d17dc79C8 # Send to a different account since self sends will first depricate balance and revert without double amount
hook=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
hookData=0x
write-local:
	cast send ${currency} "mint(address,uint256)" ${ADDRESS_LOCAL} ${escrow} --private-key ${PRIVATE_KEY_LOCAL} -- --broadcast --rpc-url ${DEPLOY_RPC_URL_LOCAL}; \
	cast send ${currency} "approve(address,uint256)" ${registrarAddress} ${escrow} --private-key ${PRIVATE_KEY_LOCAL} -- --broadcast --rpc-url ${DEPLOY_RPC_URL_LOCAL}; \
	cast send ${registrarAddress} ${writeSelector} ${currency} ${escrow} ${instant} ${owner} ${hook} ${hookData} --private-key ${PRIVATE_KEY_LOCAL} -- --broadcast --rpc-url ${DEPLOY_RPC_URL_LOCAL};

# output:  data:application/json;base64,eyJhdHRyaWJ1dGVzIjpbeyJ0cmFpdF90eXBlIjoiRVJDMjAiLCJ2YWx1ZSI6IjB4ZTdmMTcyNWU3NzM0Y2UyODhmODM2N2UxYmIxNDNlOTBiYjNmMDUxMiJ9LHsidHJhaXRfdHlwZSI6IkFtb3VudCIsImRpc3BsYXlfdHlwZSI6Im51bWJlciIsInZhbHVlIjoxMDB9LHsidHJhaXRfdHlwZSI6Ikhvb2sgQ29udHJhY3QiLCJ2YWx1ZSI6IjB4Y2Y3ZWQzYWNjYTVhNDY3ZTllNzA0YzcwM2U4ZDg3ZjYzNGZiMGZjOSJ9XX0=
tokenURI-local:
	byteString=$$(cast call ${registrarAddress} "tokenURI(uint256)" 4 --private-key ${PRIVATE_KEY_LOCAL} --rpc-url ${DEPLOY_RPC_URL_LOCAL}); \
	cast abi-decode "f(bytes)(string)" $${byteString}

setURI-local:
	echo ""; \
	denotaContractURI='{"name":"Denota Protocol (beta)","description":"The Programmable Escrow Protocol","image":"ipfs://QmZfdTBo6Pnr7qbWg4FSeSiGNHuhhmzPbHgY7n8XrZbQ2v","banner_image":"ipfs://QmVT5v2TGLuvNDcyTv9hjdga2KAnv37yFjJDYsEhGAM2zQ","external_link":"denota.xyz","collaborators":["almaraz.eth"]}' ; \
	cast send ${registrarAddress} "setContractURI(string)" "$${denotaContractURI}" --private-key ${PRIVATE_KEY_LOCAL} --rpc-url ${DEPLOY_RPC_URL_LOCAL} -- --broadcast

getURI-local:
	URI=$$(cast call ${registrarAddress} "contractURI()" --private-key ${PRIVATE_KEY_LOCAL} --rpc-url ${DEPLOY_RPC_URL_LOCAL}) ; \
	cast abi-decode "f(bytes)(string)" $${URI}

######################################################################################################################################################
#    																	Mainnet																		 #	
######################################################################################################################################################
deploy-registrar:
	forge build --optimizer-runs ${optimizer_runs}

	constructorArgs=$$(cast abi-encode "constructor(address)" ${ADDRESS}) ; \
	constructorArgs=$$(echo $${constructorArgs} | sed 's/0x//') ; \
	bytecode=$$(jq -r '.bytecode.object' ../out/NotaRegistrar.sol/NotaRegistrar.json)$${constructorArgs} ; \
	cast create2 --deployer ${FACTORY_ADDRESS} --init-code $${bytecode} --starts-with 000 --caller ${ADDRESS} 2>&1 | tee NotaRegistrar.salt.txt ; \
	salt=$$(cat NotaRegistrar.salt.txt | grep "Salt: " | awk '{print $$2}') ;
	contractAddress=$$(cat NotaRegistrar.salt.txt | grep "Address: " | awk '{print $$2}') ; 
	cast send ${FACTORY_ADDRESS} "safeCreate2(bytes32,bytes calldata)" $${salt} $${bytecode} --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL};

# TODO make chainId dynamic
verify-registrar:
	contractAddress=$$(cat NotaRegistrar.salt.txt | grep "Address: " | awk '{print $$2}') ; \
	constructorArgs=$$(cast abi-encode "constructor(address)" ${ADDRESS}) ; \
	constructorArgs=$$(echo $${constructorArgs} | sed 's/0x//') ; \
	forge verify-contract --num-of-optimizations ${optimizer_runs} --compiler-version v0.8.24 --watch \
	--constructor-args $${constructorArgs} \
	--chain-id 137 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHER_SCAN_API_KEY} \
	$${contractAddress} \
	src/NotaRegistrar.sol:NotaRegistrar

# Note: sometimes verification is skipped if block times are slow (testnets)
deploy-verify-registrar:
	forge compile --optimizer-runs ${optimizer_runs}

	constructorArgs=$$(cast abi-encode "constructor(address)" ${ADDRESS}) ; \
	constructorArgs=$$(echo $${constructorArgs} | sed 's/0x//') ; \
	bytecode=$$(jq -r '.bytecode.object' ../out/NotaRegistrar.sol/NotaRegistrar.json)$${constructorArgs} ; \
	cast create2 --deployer ${FACTORY_ADDRESS} --init-code $${bytecode} --starts-with 00000000 --caller ${ADDRESS} 2>&1 | tee NotaRegistrar.salt.txt ; \
	salt=$$(cat NotaRegistrar.salt.txt | grep "Salt: " | awk '{print $$2}') ; \
	contractAddress=$$(cat NotaRegistrar.salt.txt | grep "Address: " | awk '{print $$2}') ; \
	cast send ${FACTORY_ADDRESS} "safeCreate2(bytes32,bytes calldata)" $${salt} $${bytecode} --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL}; \
	forge verify-contract --num-of-optimizations ${optimizer_runs} --compiler-version v0.8.24 --watch \
	--constructor-args $${constructorArgs} \
	--chain-id 137 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHER_SCAN_API_KEY} \
	$${contractAddress} \
	src/NotaRegistrar.sol:NotaRegistrar

setURI:
	contractAddress=$$(cat NotaRegistrar.salt.txt | grep "Address: " | awk '{print $$2}') ; \
	denotaContractURI='{"name":"Denota Protocol (beta)","description":"The Programmable Escrow Protocol","image":"ipfs://QmZfdTBo6Pnr7qbWg4FSeSiGNHuhhmzPbHgY7n8XrZbQ2v","banner_image":"ipfs://QmVT5v2TGLuvNDcyTv9hjdga2KAnv37yFjJDYsEhGAM2zQ","external_link":"denota.xyz","collaborators":["almaraz.eth"]}' ; \
	cast send $${contractAddress} "setContractURI(string)" "${denotaContractURI}" --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL}

# Polygon addresses
CircleUSDC=0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
USDCe=0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
WETH=0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619
ENS=0xbD7A5Cf51d22930B8B3Df6d834F9BCEf90EE7c4f
DAI=0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
GET=0xdb725f82818De83e99F1dAc22A9b5B51d3d04DD4

writeSelector="write(address,uint256,uint256,address,address,bytes)"
currency=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 # deployed token address
escrow=100
instant=0
owner=${ADDRESS}
hook=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
hookData=0x
write:
	cast send ${currency} "mint(address,uint256)" ${owner} ${escrow} --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL} ; \
	cast send ${currency} "approve(address,uint256)" ${registrarAddress} ${escrow} --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL} ; \
	cast send ${registrarAddress} ${writeSelector} ${currency} ${escrow} ${instant} ${owner} ${hook} ${hookData} --private-key ${PRIVATE_KEY} --rpc-url ${DEPLOY_RPC_URL} ;

gas-registrar:
	forge test --gas-report --optimizer-runs ${optimizer_runs} | \
	grep -A 100 "src/NotaRegistrar.sol:NotaRegistrar contract" | \
	grep -v "Ran [0-9]* test suites" | \
	grep -v "FAIL" | \
	grep -E "src|-|Function|approve|burn|cash|fund|safeTransferFrom|transferFrom|tokenURI|update|write" | \
	tee NotaRegistrar.gas.txt

gas-registrar-full:
	forge test --gas-report --optimizer-runs ${optimizer_runs} | \
	grep -A 100 "src/NotaRegistrar.sol:NotaRegistrar contract" | \
	grep -v "Ran [0-9]* test suites" | \
	grep -v "FAIL" | \
	tee NotaRegistrar.gas.txt
