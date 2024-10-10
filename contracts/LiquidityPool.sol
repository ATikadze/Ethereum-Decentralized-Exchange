// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TODO: Maybe add Ownable?
contract LiquidityPool
{
    uint256 constant tokensPerShare = 10; // Tokens per 1% share
    
    address immutable thisAddress;
    address immutable token1Address;
    address immutable token2Address;

    LPToken immutable lpToken;
    IERC20 immutable token1;
    IERC20 immutable token2;

    mapping(address => mapping(address => uint256)) tokenLiquidity;

    error TokenNotSupported(address tokenAddress);
    error NoAllowance(address tokenAddress);
    error TransferFailed(address tokenAddress);

    modifier validTokens(address _token1Address, address _token2Address)
    {
        require(_tokensAreValid(_token1Address, _token2Address), "One or both tokens are not supported by this liquidity pool.");
        _;
    }
    
    constructor(address _token1Address, address _token2Address)
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

    function tokensRatioValid(uint256 _token1Amount, uint256 _token2Amount) public view returns (bool)
    {
        return token1.balanceOf(thisAddress) * _token2Amount == token2.balanceOf(thisAddress) * _token1Amount;
    }

    // -- LP Deposit methods --

    function _deposit(address _liquidityProvider, address _tokenAddress, uint256 _tokenAmount) private
    {
        IERC20 token = _getToken(_tokenAddress);

        if (token.allowance(_liquidityProvider, thisAddress) < _tokenAmount)
            revert NoAllowance(_tokenAddress);

        if (!token.transferFrom(_liquidityProvider, thisAddress, _tokenAmount))
            revert TransferFailed(_tokenAddress);

        tokenLiquidity[_liquidityProvider][address(token)] += _tokenAmount;
    }

    function deposit(address _liquidityProvider, address _token1Address, address _token2Address, uint256 _token1Amount, uint256 _token2Amount) external validTokens(_token1Address, _token2Address)
    {
        require(tokensRatioValid(_token1Amount, _token2Amount), "Ratio of the deposited tokens must match.");
        
        _deposit(_liquidityProvider, _token1Address, _token1Amount);
        _deposit(_liquidityProvider, _token2Address, _token2Amount);
        
        uint256 _lpTokens = _token1Amount * 100 / token1.balanceOf(thisAddress);

        lpToken.mint(_liquidityProvider, _lpTokens);
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

        require(_tokenOutBalance > _tokenOutAmount);

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

        return _getInAmount(_tokenInBalance, _tokenOutBalance, _tokenOutAmount);
    }
    
    // TODO: Add LP fee
    function swap(address _account, address _tokenInAddress, address _tokenOutAddress, uint256 _tokenInAmount, uint256 _tokenOutMinAmount) external validTokens(_tokenInAddress, _tokenOutAddress)
    {
        IERC20 _inToken = _getToken(_tokenInAddress);

        require(_inToken.allowance(_account, thisAddress) >= _tokenInAmount);
        
        (uint256 _tokenInBalance, uint256 _tokenOutBalance) = _getBalances(_tokenInAddress, _tokenOutAddress);
        
        uint256 _availableTokenOutAmount = _getOutAmount(_tokenInBalance, _tokenOutBalance, _tokenInAmount);

        require(_availableTokenOutAmount >= _tokenOutMinAmount);

        require(_inToken.transferFrom(_account, thisAddress, _tokenInAmount));

        require(_getToken(_tokenOutAddress).transfer(_account, _availableTokenOutAmount));
    }
}
