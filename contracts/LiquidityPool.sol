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

    error NoAllowance(address tokenAddress);
    error TransferFailed(address tokenAddress);

    modifier validTokens(address _token1Address, address _token2Address)
    {
        require(tokensAreValid(_token1Address, _token2Address), "One or both tokens are not supported by this liquidity pool.");
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

    function tokensAreValid(address _token1Address, address _token2Address) internal view returns (bool)
    {
        return ((_token1Address == token1Address || _token2Address == token2Address) || (_token1Address == token2Address || _token2Address == token1Address));
    }

    function tokensRatioValid(uint256 _token1Amount, uint256 _token2Amount) public view returns (bool)
    {
        return token1.balanceOf(thisAddress) * _token2Amount == token2.balanceOf(thisAddress) * _token1Amount;
    }

    function deposit(address _liquidityProvider, address _token1Address, address _token2Address, uint256 _token1Amount, uint256 _token2Amount) external validTokens(_token1Address, _token2Address)
    {
        require(tokensRatioValid(_token1Amount, _token2Amount), "Ratio of the deposited tokens must match.");
        
        deposit(_liquidityProvider, _token1Address, _token1Amount);
        deposit(_liquidityProvider, _token2Address, _token2Amount);
        
        uint256 _lpTokens = _token1Amount * 100 / token1.balanceOf(thisAddress);

        lpToken.mint(_liquidityProvider, _lpTokens);
    }

    function deposit(address _liquidityProvider, address _tokenAddress, uint256 _tokenAmount) private
    {
        IERC20 token;

        if (token1Address == _tokenAddress)
            token = token1;
        else if (token2Address == _tokenAddress)
            token = token2;
        else
            revert();
        
        if (token.allowance(_liquidityProvider, thisAddress) < _tokenAmount)
            revert NoAllowance(_tokenAddress);

        if (!token.transferFrom(_liquidityProvider, thisAddress, _tokenAmount))
            revert TransferFailed(_tokenAddress);

        tokenLiquidity[_liquidityProvider][address(token)] += _tokenAmount;
    }
}
