// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20, Ownable
{
    constructor() ERC20("Liquidity Provider Token", "LPT") Ownable(msg.sender) {}

    function mint(address _account, uint256 _value) external onlyOwner
    {
        _mint(_account, _value);
    }

    function burn(address _account, uint256 _value) external onlyOwner {
        _burn(_account, _value);
    }
}
