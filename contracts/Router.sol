// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "./Interfaces/ICustomWETH.sol";
import "./Interfaces/IETHErrors.sol";
import "./Interfaces/ITokenErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Router is ReentrancyGuard, IETHErrors, ITokenErrors
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
        require(msg.sender == wethAddress, "Only accepting Ether from WETH contract.");
    }
    
    function _tokensOrdered(address _token1Address, address _token2Address) internal pure returns (bool)
    {
        return _token1Address < _token2Address ? true : false;
    }
    
    function _getOrderedTokens(address _token1Address, address _token2Address) internal pure returns (address _tokenA, address _tokenB)
    {
        (_tokenA, _tokenB) = _tokensOrdered(_token1Address, _token2Address) ? (_token1Address, _token2Address) : (_token2Address, _token1Address);
    }
    
    function _getLiquidityPoolIdentifier(address _token1Address, address _token2Address) internal pure returns (bytes32)
    {
        (address _tokenA, address _tokenB) = _getOrderedTokens(_token1Address, _token2Address);
        
        return keccak256(abi.encodePacked(_tokenA, _tokenB));
    }

    function getLiquidityPoolAddress(address _token1Address, address _token2Address) external view returns (address)
    {
        return address(liquidityPools[_getLiquidityPoolIdentifier(_token1Address, _token2Address)]);
    }
    
    function wrapEther() external payable nonReentrant
    {
        if (msg.value == 0)
            revert InsufficientEtherSent(msg.value, 0);

        wethContract.deposit{value: msg.value}();
        wethContract.transfer(msg.sender, msg.value);
    }

    function unwrapEther(uint256 _wethAmount) external nonReentrant
    {
        if (_wethAmount == 0)
            revert InsufficientTokenSent(_wethAmount, 0, wethAddress);

        if (!wethContract.transferFrom(msg.sender, address(this), _wethAmount))
            revert TokenTransferFailed(msg.sender, address(this), _wethAmount, wethAddress);
        
        wethContract.withdraw(_wethAmount);
        (bool _success, ) = msg.sender.call{value: _wethAmount}("");

        if (!_success)
            revert ETHTransferFailed(msg.sender, _wethAmount);
    }
    
    function deposit(address _token1Address, address _token2Address, uint256 _token1Amount, uint256 _token2Amount) external
    {
        bytes32 _liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);

        if (address(liquidityPools[_liquidityPoolIdentifier]) == address(0))
        {
            (address _tokenA, address _tokenB) = _getOrderedTokens(_token1Address, _token2Address);
            liquidityPools[_liquidityPoolIdentifier] = new LiquidityPool(_tokenA, _tokenB);
        }

        (uint256 _tokenAAmount, uint256 _tokenBAmount) = _tokensOrdered(_token1Address, _token2Address) ? (_token1Amount, _token2Amount) : (_token2Amount, _token1Amount);

        liquidityPools[_liquidityPoolIdentifier].deposit(msg.sender, _tokenAAmount, _tokenBAmount);
    }

    function withdraw(address _token1Address, address _token2Address, uint256 _percentage) external liquidityPoolExists(_token1Address, _token2Address)
    {
        bytes32 _liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);
        
        liquidityPools[_liquidityPoolIdentifier].withdraw(msg.sender, _percentage);
    }
    
    function swap(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount, uint256 _tokenOutMinAmount) external liquidityPoolExists(_tokenInAddress, _tokenOutAddress)
    {
        bytes32 _liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_tokenInAddress, _tokenOutAddress);
        
        liquidityPools[_liquidityPoolIdentifier].swap(msg.sender, _tokenInAddress, _tokenOutAddress, _tokenInAmount, _tokenOutMinAmount);
    }
}