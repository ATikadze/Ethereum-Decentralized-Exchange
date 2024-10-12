// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LPToken.sol";
import "./Interfaces/IETHErrors.sol";
import "./Interfaces/ITokenErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LiquidityPool Contract
/// @author Alexander Tikadze
/// @notice Manages liquidity provision, token swaps, and liquidity withdrawals for a specific token pair.
contract LiquidityPool is Ownable, ReentrancyGuard, IETHErrors, ITokenErrors
{
    /// @notice Tokens per 1% share
    uint256 constant tokensPerShare = 10;
    
    /// @notice 0.3% swap fee (divided by 1000 later)
    uint256 constant swapFee = 3;

    /// @notice The address of this liquidity pool
    address immutable thisAddress;
    
    /// @notice The address of the first token in the pair
    address immutable token1Address;
    
    /// @notice The address of the second token in the pair
    address immutable token2Address;

    /// @notice LP Token contract for liquidity providers
    LPToken immutable lpToken;
    
    /// @notice ERC20 interface for the first token in the pair
    IERC20 immutable token1;
    
    /// @notice ERC20 interface for the second token in the pair
    IERC20 immutable token2;

    /// @notice Error triggered when tokens are not supported by this liquidity pool
    error TokensNotSupported();
    
    /// @notice Error triggered when a token is not supported by this pool
    error TokenNotSupported(address tokenAddress);
    
    /// @notice Error triggered when the token ratio provided is invalid
    error InvalidTokensRatio();
    
    /// @notice Error triggered when the swap output amount is less than the minimum required
    error SwapFailedMinOutAmount(uint256 tokenOutMinAmount, uint256 availableTokenOutAmount);

    /// @notice Event emitted when liquidity is deposited
    /// @param liquidityProvider Address of the liquidity provider
    /// @param token1Amount Amount of token1 deposited
    /// @param token2Amount Amount of token2 deposited
    event Deposited(address liquidityProvider, uint256 token1Amount, uint256 token2Amount);
    
    /// @notice Event emitted when liquidity is withdrawn
    /// @param liquidityProvider Address of the liquidity provider
    /// @param percentage Percentage of liquidity withdrawn
    event Withdrawn(address liquidityProvider, uint256 percentage);
    
    /// @notice Event emitted when tokens are swapped
    /// @param account Address performing the swap
    /// @param tokenInAddress Address of the token being swapped (input)
    /// @param tokenOutAddress Address of the token being received (output)
    /// @param tokenInAmount Amount of the input token
    /// @param tokenOutAmount Amount of the output token received
    event Swapped(address account, address tokenInAddress, address tokenOutAddress, uint256 tokenInAmount, uint256 tokenOutAmount);

    /// @notice Modifier to check if tokens are valid for this pool
    /// @param _token1Address Address of the first token
    /// @param _token2Address Address of the second token
    modifier validTokens(address _token1Address, address _token2Address)
    {
        if (!_tokensAreValid(_token1Address, _token2Address))
            revert TokensNotSupported();
            
        _;
    }
    
    /// @notice Constructor to initialize the liquidity pool with two tokens
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    constructor(address _token1Address, address _token2Address)
    Ownable(msg.sender)
    {
        thisAddress = address(this);
        token1Address = _token1Address;
        token2Address = _token2Address;

        lpToken = new LPToken();
        token1 = IERC20(_token1Address);
        token2 = IERC20(_token2Address);
    }

    // -- Helper methods --

    /// @notice Internal function to return the correct ERC20 token instance for the provided token address
    /// @param _tokenAddress The address of the token
    /// @return The ERC20 token instance
    function _getToken(address _tokenAddress) internal view returns (IERC20)
    {
        if (token1Address == _tokenAddress)
            return token1;
        else if (token2Address == _tokenAddress)
            return token2;
        else
            revert TokenNotSupported(_tokenAddress);
    }

    /// @notice Internal function to retrieve balances of both tokens in the liquidity pool
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return _token1Balance Balance of token1 in the pool
    /// @return _token2Balance Balance of token2 in the pool
    function _getBalances(address _token1Address, address _token2Address) internal view returns (uint256 _token1Balance, uint256 _token2Balance)
    {
        _token1Balance = _getToken(_token1Address).balanceOf(thisAddress);
        _token2Balance = _getToken(_token2Address).balanceOf(thisAddress);
    }

    /// @notice Internal function to check if the token pair is valid for this liquidity pool
    /// @param _token1Address The address of the first token
    /// @param _token2Address The address of the second token
    /// @return True if the tokens are valid, false otherwise
    function _tokensAreValid(address _token1Address, address _token2Address) internal view returns (bool)
    {
        return ((_token1Address == token1Address || _token2Address == token2Address) || (_token1Address == token2Address || _token2Address == token1Address));
    }

    /// @notice Internal function to check if the token ratios are valid for deposit
    /// @param _token1Amount Amount of the first token
    /// @param _token2Amount Amount of the second token
    /// @return True if the ratios are valid, false otherwise
    function _tokensRatioValid(uint256 _token1Amount, uint256 _token2Amount) internal view returns (bool)
    {
        return token1.balanceOf(thisAddress) * _token2Amount == token2.balanceOf(thisAddress) * _token1Amount;
    }

    // -- LP Deposit methods --

    /// @notice Internal function to deposit tokens into the liquidity pool
    /// @param _liquidityProvider Address of the liquidity provider
    /// @param _tokenAddress The address of the token being deposited
    /// @param _tokenAmount The amount of the token being deposited
    function _deposit(address _liquidityProvider, address _tokenAddress, uint256 _tokenAmount) internal
    {
        IERC20 token = _getToken(_tokenAddress);
        
        uint256 _availableTokenAllowance = token.allowance(_liquidityProvider, thisAddress);

        if (_availableTokenAllowance < _tokenAmount)
            revert NotEnoughTokenAllowance(_liquidityProvider, thisAddress, _tokenAmount, _availableTokenAllowance, _tokenAddress);

        if (!token.transferFrom(_liquidityProvider, thisAddress, _tokenAmount))
            revert TokenTransferFailed(_liquidityProvider, thisAddress, _tokenAmount, _tokenAddress);
    }

    /// @notice Deposits token pairs into the liquidity pool
    /// @param _liquidityProvider Address of the liquidity provider
    /// @param _token1Amount Amount of the first token to deposit
    /// @param _token2Amount Amount of the second token to deposit
    function deposit(address _liquidityProvider, uint256 _token1Amount, uint256 _token2Amount) external onlyOwner nonReentrant
    {
        if (!_tokensRatioValid(_token1Amount, _token2Amount))
            revert InvalidTokensRatio();
        
        _deposit(_liquidityProvider, token1Address, _token1Amount);
        _deposit(_liquidityProvider, token2Address, _token2Amount);
        
        uint256 _lpTokens = _token1Amount * 100 * tokensPerShare / token1.balanceOf(thisAddress);

        lpToken.mint(_liquidityProvider, _lpTokens);

        emit Deposited(_liquidityProvider, _token1Amount, _token2Amount);
    }

    // -- LP Withdrawal methods --

    /// @notice Withdraws a percentage of liquidity from the pool
    /// @param _liquidityProvider Address of the liquidity provider
    /// @param _percentage The percentage of liquidity to withdraw (0-100)
    function withdraw(address _liquidityProvider, uint256 _percentage) external onlyOwner nonReentrant
    {
        require(_percentage > 0 && _percentage <= 100, "Percentage must be within 0 and 100 range.");
        
        uint256 _lpTokensToWithdraw = lpToken.balanceOf(_liquidityProvider) * _percentage / 100;
        
        // Multiplying by 1e18 for better precision
        uint256 _lpTokensSharePercentage = _lpTokensToWithdraw * 1e18 / lpToken.totalSupply();

        lpToken.burn(_liquidityProvider, _lpTokensToWithdraw);

        token1.transfer(_liquidityProvider, token1.balanceOf(thisAddress) * _lpTokensSharePercentage / 1e18);
        token2.transfer(_liquidityProvider, token2.balanceOf(thisAddress) * _lpTokensSharePercentage / 1e18);

        emit Withdrawn(_liquidityProvider, _percentage);
    }
    
    // -- Swap methods --

    /// @notice Internal function to calculate the output amount in a swap
    /// @param _tokenInBalance Balance of the input token in the pool
    /// @param _tokenOutBalance Balance of the output token in the pool
    /// @param _tokenInAmount Amount of input token being swapped
    /// @return The amount of output token to receive
    function _getOutAmount(uint256 _tokenInBalance, uint256 _tokenOutBalance, uint256 _tokenInAmount) internal pure returns (uint256)
    {
        uint256 k = _tokenInBalance * _tokenOutBalance;

        return _tokenOutBalance - (k / (_tokenInBalance + _tokenInAmount));
    }
    
    /// @notice Internal function to calculate the required input amount in a swap
    /// @param _tokenInBalance Balance of the input token in the pool
    /// @param _tokenOutBalance Balance of the output token in the pool
    /// @param _tokenOutAmount Amount of output token needed
    /// @return The amount of input token required for the swap
    function _getInAmount(uint256 _tokenInBalance, uint256 _tokenOutBalance, uint256 _tokenOutAmount) internal pure returns (uint256)
    {
        uint256 k = _tokenInBalance * _tokenOutBalance;

        return (k / (_tokenOutBalance - _tokenOutAmount)) - _tokenInBalance;
    }
    
    /// @notice Returns the output amount for a swap between two tokens
    /// @param _tokenInAddress The address of the input token
    /// @param _tokenOutAddress The address of the output token
    /// @param _tokenInAmount The amount of input token being swapped
    /// @return The amount of output token to receive
    function getOutAmount(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount) public view validTokens(_tokenInAddress, _tokenOutAddress) returns (uint256)
    {
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);

        return _getOutAmount(_tokenInBalance, _tokenOutBalance, _tokenInAmount);
    }
    
    /// @notice Returns the input amount required for a swap between two tokens
    /// @param _tokenInAddress The address of the input token
    /// @param _tokenOutAddress The address of the output token
    /// @param _tokenOutAmount The amount of output token desired
    /// @return The amount of input token required for the swap
    function getInAmount(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenOutAmount) public view validTokens(_tokenInAddress, _tokenOutAddress) returns (uint256)
    {
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);

        if (_tokenOutBalance < _tokenOutAmount)
            revert InsufficientTokenBalance(_tokenOutAmount, _tokenOutBalance, _tokenOutAddress);

        return _getInAmount(_tokenInBalance, _tokenOutBalance, _tokenOutAmount);
    }
    
    /// @notice Executes a token swap between two tokens in the liquidity pool
    /// @param _account The address performing the swap
    /// @param _tokenInAddress The address of the input token
    /// @param _tokenOutAddress The address of the output token
    /// @param _tokenInAmount The amount of input token
    /// @param _tokenOutMinAmount The minimum amount of output token required
    function swap(address _account, address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount, uint256 _tokenOutMinAmount) external onlyOwner validTokens(_tokenInAddress, _tokenOutAddress) nonReentrant
    {
        IERC20 _inToken = _getToken(_tokenInAddress);
        
        uint256 _availableTokenInAllowance = _inToken.allowance(_account, thisAddress);

        if (_availableTokenInAllowance < _tokenInAmount)
            revert NotEnoughTokenAllowance(_account, thisAddress, _tokenInAmount, _availableTokenInAllowance, _tokenInAddress);
        
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);

        uint256 _fee = (_tokenInAmount * swapFee / 1000);
        
        uint256 _availableTokenOutAmount = _getOutAmount(_tokenInBalance, _tokenOutBalance, _tokenInAmount - _fee);

        if (_availableTokenOutAmount < _tokenOutMinAmount)
            revert SwapFailedMinOutAmount(_tokenOutMinAmount, _availableTokenOutAmount);

        if (!_inToken.transferFrom(_account, thisAddress, _tokenInAmount))
            revert TokenTransferFailed(_account, thisAddress, _tokenInAmount, _tokenInAddress);

        if (!_getToken(_tokenOutAddress).transfer(_account, _availableTokenOutAmount))
            revert TokenTransferFailed(thisAddress, _account, _availableTokenOutAmount, _tokenOutAddress);

        emit Swapped(_account, _tokenInAddress, _tokenOutAddress, _tokenInAmount, _availableTokenOutAmount);
    }
}
