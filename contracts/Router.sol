// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";

contract Router
{
    mapping(bytes32 => LiquidityPool) liquidityPools;
    
    function getLiquidityPoolIdentifier(address _token1Address, address _token2Address) private pure returns (bytes32)
    {
        (address _tokenA, address _tokenB) = _token1Address < _token2Address ? (_token1Address, _token2Address) : (_token2Address, _token1Address);
        
        return keccak256(abi.encodePacked(_tokenA, _tokenB));
    }

    /* function depositETHToToken(address tokenAddress) external
    {
    } */

    function getLiquidityPoolAddress(address _token1Address, address _token2Address) external view returns (address)
    {
        return address(liquidityPools[getLiquidityPoolIdentifier(_token1Address, _token2Address)]);
    }
    
    function deposit(address _token1Address, address _token2Address, uint256 _token1Amount, uint256 _token2Amount) external
    {
        bytes32 liquidityPoolIdentifier = getLiquidityPoolIdentifier(_token1Address, _token2Address);
        //LiquidityPool liquidityPool = liquidityPools[poolIdentifier];

        if (address(liquidityPools[liquidityPoolIdentifier]) == address(0))
            liquidityPools[liquidityPoolIdentifier] = new LiquidityPool(_token1Address, _token2Address);

        liquidityPools[liquidityPoolIdentifier].deposit(msg.sender, _token1Address, _token2Address, _token1Amount, _token2Amount);
    }
}