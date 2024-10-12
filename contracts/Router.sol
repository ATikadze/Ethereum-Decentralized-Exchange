// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LiquidityPool.sol";
import "./Interfaces/ICustomWETH.sol";
import "./Interfaces/IETHErrors.sol";
import "./Interfaces/ITokenErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Router Contract
/// @author Alexander Tikadze
/// @notice Manages token swaps, liquidity deposits, withdrawals, and WETH wrapping/unwrapping.
contract Router is ReentrancyGuard, IETHErrors, ITokenErrors
{
    /// @notice The address of the Wrapped Ether (WETH) contract
    address immutable wethAddress;
    
    /// @notice Interface for the Wrapped Ether (WETH) contract
    ICustomWETH immutable wethContract;
    
    /// @notice Mapping to store liquidity pools identified by token pairs
    mapping(bytes32 => LiquidityPool) liquidityPools;

    /// @notice Error triggered when no liquidity pool is found for the given token pair
    error NoLiquidityPoolFound(address token1, address token2);

    /// @notice Modifier to check if the liquidity pool exists for the given token pair
    /// @param _token1Address The address of the first token in the pair
    /// @param _token2Address The address of the second token in the pair
    modifier liquidityPoolExists(address _token1Address, address _token2Address)
    {
        bytes32 liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);

        if (address(liquidityPools[liquidityPoolIdentifier]) == address(0))
            revert NoLiquidityPoolFound(_token1Address, _token2Address);

        _;
    }

    /// @notice Constructor to initialize the WETH contract address
    /// @param _wethAddress The address of the WETH contract
    constructor(address _wethAddress)
    {
        wethAddress = _wethAddress;
        wethContract = ICustomWETH(_wethAddress);
    }

    /// @notice Allows the contract to accept ETH, but only from the WETH contract
    receive() external payable
    {
        require(msg.sender == wethAddress, "Only accepting Ether from WETH contract.");
    }
    
    /// @notice Determines the correct ordering of token addresses
    /// @dev Ensures that token addresses are consistently ordered
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return True if _token1Address < _token2Address, false otherwise
    function _tokensOrdered(address _token1Address, address _token2Address) internal pure returns (bool)
    {
        return _token1Address < _token2Address;
    }
    
    /// @notice Orders the token addresses and returns them
    /// @dev This ensures the token pairs are stored consistently in liquidity pools
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return _tokenA The address of the first token in the correct order
    /// @return _tokenB The address of the second token in the correct order
    function _getOrderedTokens(address _token1Address, address _token2Address) internal pure returns (address _tokenA, address _tokenB)
    {
        (_tokenA, _tokenB) = _tokensOrdered(_token1Address, _token2Address) ? (_token1Address, _token2Address) : (_token2Address, _token1Address);
    }
    
    /// @notice Generates a unique identifier for a liquidity pool based on the token pair
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return The identifier for the liquidity pool
    function _getLiquidityPoolIdentifier(address _token1Address, address _token2Address) internal pure returns (bytes32)
    {
        (address _tokenA, address _tokenB) = _getOrderedTokens(_token1Address, _token2Address);
        
        return keccak256(abi.encodePacked(_tokenA, _tokenB));
    }

    /// @notice Retrieves the address of a liquidity pool for the given token pair
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return The address of the liquidity pool
    function getLiquidityPoolAddress(address _token1Address, address _token2Address) external view returns (address)
    {
        return address(liquidityPools[_getLiquidityPoolIdentifier(_token1Address, _token2Address)]);
    }
    
    /// @notice Wraps ETH into WETH and sends it to the sender
    /// @dev The user sends ETH and receives the equivalent amount of WETH
    function wrapEther() external payable nonReentrant
    {
        if (msg.value == 0)
            revert InsufficientEtherSent(msg.value, 0);

        wethContract.deposit{value: msg.value}();
        wethContract.transfer(msg.sender, msg.value);
    }

    /// @notice Unwraps WETH into ETH and sends it to the sender
    /// @param _wethAmount The amount of WETH to unwrap into ETH
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
    
    /// @notice Deposits tokens into a liquidity pool, creating one if it doesn't exist
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @param _token1Amount The amount of the first token to deposit
    /// @param _token2Amount The amount of the second token to deposit
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

    /// @notice Withdraws liquidity from a pool based on the provided percentage
    /// @param _token1Address The address of the first token in the pair
    /// @param _token2Address The address of the second token in the pair
    /// @param _percentage The percentage of liquidity to withdraw (0-100)
    function withdraw(address _token1Address, address _token2Address, uint256 _percentage) external liquidityPoolExists(_token1Address, _token2Address)
    {
        bytes32 _liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_token1Address, _token2Address);
        liquidityPools[_liquidityPoolIdentifier].withdraw(msg.sender, _percentage);
    }
    
    /// @notice Swaps tokens in a liquidity pool
    /// @param _tokenInAddress The address of the token being swapped (input)
    /// @param _tokenOutAddress The address of the token being received (output)
    /// @param _tokenInAmount The amount of the input token
    /// @param _tokenOutMinAmount The minimum amount of the output token to receive
    function swap(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount, uint256 _tokenOutMinAmount) external liquidityPoolExists(_tokenInAddress, _tokenOutAddress)
    {
        bytes32 _liquidityPoolIdentifier = _getLiquidityPoolIdentifier(_tokenInAddress, _tokenOutAddress);
        liquidityPools[_liquidityPoolIdentifier].swap(msg.sender, _tokenInAddress, _tokenOutAddress, _tokenInAmount, _tokenOutMinAmount);
    }
}