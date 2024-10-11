// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LPToken.sol";
import "./Interfaces/IETHErrors.sol";
import "./Interfaces/ITokenErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidityPool is Ownable, ReentrancyGuard, IETHErrors, ITokenErrors
{
    uint256 constant tokensPerShare = 10; // Tokens per 1% share
    uint256 constant swapFee = 3; // 0.3 (will later divide the result by 10)
    
    address immutable thisAddress;
    address immutable token1Address;
    address immutable token2Address;

    LPToken immutable lpToken;
    IERC20 immutable token1;
    IERC20 immutable token2;

    error TokensNotSupported();
    error TokenNotSupported(address tokenAddress);
    error InvalidTokensRatio();
    error SwapFailedMinOutAmount(uint256 tokenOutMinAmount, uint256 availableTokenOutAmount);

    event Deposited(address liquidityProvider, uint256 token1Amount, uint256 token2Amount);
    event Withdrawn(address liquidityProvider, uint256 percentage);
    event Swapped(address account, address tokenInAddress, address tokenOutAddress, uint256 tokenInAmount, uint256 tokenOutAmount);

    modifier validTokens(address _token1Address, address _token2Address)
    {
        if (!_tokensAreValid(_token1Address, _token2Address))
            revert TokensNotSupported();
            
        _;
    }
    
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

    function _getToken(address _tokenAddress) internal view returns (IERC20)
    {
        if (token1Address == _tokenAddress)
            return token1;
        else if (token2Address == _tokenAddress)
            return token2;
        else
            revert TokenNotSupported(_tokenAddress);
    }

    function _getBalances(address _token1Address, address _token2Address) internal view returns (uint256 _token1Balance, uint256 _token2Balance)
    {
        _token1Balance = _getToken(_token1Address).balanceOf(thisAddress);
        _token2Balance = _getToken(_token2Address).balanceOf(thisAddress);
    }

    function _tokensAreValid(address _token1Address, address _token2Address) internal view returns (bool)
    {
        return ((_token1Address == token1Address || _token2Address == token2Address) || (_token1Address == token2Address || _token2Address == token1Address));
    }

    function _tokensRatioValid(uint256 _token1Amount, uint256 _token2Amount) internal view returns (bool)
    {
        return token1.balanceOf(thisAddress) * _token2Amount == token2.balanceOf(thisAddress) * _token1Amount;
    }

    // -- LP Deposit methods --

    function _deposit(address _liquidityProvider, address _tokenAddress, uint256 _tokenAmount) internal
    {
        IERC20 token = _getToken(_tokenAddress);
        
        uint256 _availableTokenAllowance = token.allowance(_liquidityProvider, thisAddress);

        if (_availableTokenAllowance < _tokenAmount)
            revert NotEnoughTokenAllowance(_liquidityProvider, thisAddress, _tokenAmount, _availableTokenAllowance, _tokenAddress);

        if (!token.transferFrom(_liquidityProvider, thisAddress, _tokenAmount))
            revert TokenTransferFailed(_liquidityProvider, thisAddress, _tokenAmount, _tokenAddress);
    }

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

    function _getOutAmount(uint256 _tokenInBalance, uint256 _tokenOutBalance, uint256 _tokenInAmount) internal pure returns (uint256)
    {
        uint256 k = _tokenInBalance * _tokenOutBalance;

        return _tokenOutBalance - (k / (_tokenInBalance + _tokenInAmount));
        // Example: 10 - (10 000 / (1000 + 250)) = 2
    }
    
    function _getInAmount(uint256 _tokenInBalance, uint256 _tokenOutBalance, uint256 _tokenOutAmount) internal pure returns (uint256)
    {
        uint256 k = _tokenInBalance * _tokenOutBalance;

        return (k / (_tokenOutBalance - _tokenOutAmount)) - _tokenInBalance;
        // Example: (10 000 / (10 - 2)) - 1000 = 250
    }
    
    function getOutAmount(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount) public view validTokens(_tokenInAddress, _tokenOutAddress) returns (uint256)
    {
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);

        return _getOutAmount(_tokenInBalance, _tokenOutBalance, _tokenInAmount);
    }
    
    function getInAmount(address _tokenInAddress, address _tokenOutAddress, uint256 _tokenOutAmount) public view validTokens(_tokenInAddress, _tokenOutAddress) returns (uint256)
    {
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);

        if (_tokenOutBalance < _tokenOutAmount)
            revert InsufficientTokenBalance(_tokenOutAmount, _tokenOutBalance, _tokenOutAddress);

        return _getInAmount(_tokenInBalance, _tokenOutBalance, _tokenOutAmount);
    }
    
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
