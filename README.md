# Arbitrage-Example

There were just no good up to date Uniswap V2 Arbitrage Examples so I made one

Test via

```
forge test --fork-url <RPC Node endpoint here>
```

## Notes on Effiency

- Rewrite in Yul+ since the repayment math does need to be safe but solidity safemath is horrible in effiency
- getPair can be derived inside the contract through a function like [this](https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol#L18) but including factory init code hash is confusing for people
