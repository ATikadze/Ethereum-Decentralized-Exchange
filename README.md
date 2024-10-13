# Ethereum Decentralized Exchange (DEX)

#### About:

This Decentralized Exchange (DEX) allows users to swap tokens, provide liquidity, and earn rewards. The project is composed of three main contracts: Router, LiquidityPool, and LPToken, each of which plays a crucial role in facilitating the exchange’s core functionalities.

* Router: This is the main entry point for users interacting with the DEX. It manages token swaps, liquidity provision, and withdrawals. It also supports wrapping and unwrapping Ether using WETH, and it dynamically creates new liquidity pools for token pairs as needed.
*	LiquidityPool: This contract manages liquidity for specific token pairs, allowing users to deposit tokens in exchange for LP Tokens, which represent their share of the pool. It also handles token swaps using the Automated Market Maker (AMM) model, applying a small swap fee that is distributed to liquidity providers.
*	LPToken: These are ERC20 tokens that represent the user’s share in a liquidity pool. The contract mints new tokens when liquidity is added to the pool and burns tokens when liquidity is withdrawn, ensuring that users’ ownership of the pool is accurately tracked.

The DEX is designed for secure and decentralized token trading, allowing users to benefit from liquidity provision and efficient swaps, all while integrating popular standards like ERC20 and WETH.


#### Architecture:
![Architecture Diagram](https://github.com/ATikadze/Ethereum-Decentralized-Exchange--DEX-/blob/06a0639044b5a979f21c94ebb973379f7529403a/assets/Architecture.png)


#### Testing:
For testing, try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
```
