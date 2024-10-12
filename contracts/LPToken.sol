// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LPToken Contract
/// @author Alexander Tikadze
/// @notice ERC20 token representing liquidity provider shares in the liquidity pool.
contract LPToken is ERC20, Ownable
{
    /// @notice Constructor to initialize the LPToken with name and symbol
    constructor() ERC20("Liquidity Provider Token", "LPT") Ownable(msg.sender) {}

    /// @notice Mints LP tokens to a liquidity provider
    /// @param _account The address of the liquidity provider
    /// @param _value The amount of LP tokens to mint
    function mint(address _account, uint256 _value) external onlyOwner
    {
        _mint(_account, _value);
    }

    /// @notice Burns LP tokens from a liquidity provider
    /// @param _account The address of the liquidity provider
    /// @param _value The amount of LP tokens to burn
    function burn(address _account, uint256 _value) external onlyOwner
    {
        _burn(_account, _value);
    }
}
