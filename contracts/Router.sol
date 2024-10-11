// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "./Interfaces/ICustomWETH.sol";

contract Router
{
    address immutable wethAddress;
    
    ICustomWETH immutable wethContract;
    
    mapping(bytes32 => LiquidityPool) liquidityPools;

    error NoLiquidityPoolFound(address token1, address token2);

    modifier liquidityPoolExists(address _token1Address, address _token2Address)
    {
        bytes32 liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);

        if (address(liquidityPools[liquidityPoolIdentifier]) == address(0))
            revert NoLiquidityPoolFound(_token1Address, _token2Address);

        _;
    }

    constructor(address _wethAddress)
    {
        wethAddress = _wethAddress;
        wethContract = ICustomWETH(_wethAddress);
    }

    receive() external payable
    {
        require(msg.sender == wethAddress);
    }
    
    function _getLiquidityPoolIdentifier(address _token1Address, address _token2Address) private pure returns (bytes32)
    {
        (address _tokenA, address _tokenB) = _token1Address < _token2Address ? (_token1Address, _token2Address) : (_token2Address, _token1Address);
        
        return keccak256(abi.encodePacked(_tokenA, _tokenB));
    }

    function getLiquidityPoolAddress(address _token1Address, address _token2Address) external view returns (address)
    {
        return address(liquidityPools[_getLiquidityPoolIdentifier(_token1Address, _token2Address)]);
    }
    
    function wrapEther() external payable
    {
        require(msg.value > 0);

        wethContract.deposit{value: msg.value}();
        wethContract.transfer(msg.sender, msg.value);
    }

    function unwrapEther(uint256 _amount) external
    {
        require(_amount > 0);
        require(wethContract.transferFrom(msg.sender, address(this), _amount));
        
        wethContract.withdraw(_amount);
        (bool _success, ) = msg.sender.call{value: _amount}("");

        require(_success);
    }
    
    function deposit(address _token1Address, address _token2Address, uint256 _token1Amount, uint256 _token2Amount) external
    {
        bytes32 liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);

        if (address(liquidityPools[liquidityPoolIdentifier]) == address(0))
            liquidityPools[liquidityPoolIdentifier] = new LiquidityPool(_token1Address, _token2Address);

        liquidityPools[liquidityPoolIdentifier].deposit(msg.sender, _token1Address, _token2Address, _token1Amount, _token2Amount);
    }

    function withdraw(address _token1Address, address _token2Address, uint256 _percentage) external liquidityPoolExists(_token1Address, _token2Address)
    {
        bytes32 liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);
        
        liquidityPools[liquidityPoolIdentifier].withdraw(msg.sender, _percentage);
    }
    
    function swap(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount, uint256 _tokenOutMinAmount) external liquidityPoolExists(_tokenInAddress, _tokenOutAddress)
    {
        bytes32 liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_tokenInAddress, _tokenOutAddress);
        
        liquidityPools[liquidityPoolIdentifier].swap(msg.sender, _tokenInAddress, _tokenOutAddress, _tokenInAmount, _tokenOutMinAmount);
    }
}