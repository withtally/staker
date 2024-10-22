.PHONY: test

clean:
	forge clean

build:
	forge build

test:
	forge test

gas:
	WRITE_REPORT=true forge test --mp test/gas-reports/*.g.sol --isolate
