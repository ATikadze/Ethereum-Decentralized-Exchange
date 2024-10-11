// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

interface ICustomWETH is IWETH {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}
