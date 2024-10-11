// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITokenErrors {
    
    /// @notice Thrown when an operation requires more tokens than is available.
    /// @param requested The amount of tokens requested.
    /// @param available The amount of tokens available.
    /// @param tokenAddress Address of the token.
    error InsufficientTokenBalance(uint256 requested, uint256 available, address tokenAddress);

    /// @notice Thrown when the amount of tokens sent is less than required.
    /// @param received The amount of tokens received.
    /// @param minimumRequired The minimum required tokens for the operation.
    /// @param tokenAddress Address of the token.
    error InsufficientTokenSent(uint256 received, uint256 minimumRequired, address tokenAddress);

    /// @notice Thrown when requested token allowance exceeds available allowance.
    /// @param owner The address of the token owner.
    /// @param spender The address of the spender.
    /// @param requestedAllowance The amount of allowance requested.
    /// @param availableAllowance The available allowance for the spender.
    /// @param tokenAddress Address of the token.
    error NotEnoughTokenAllowance(address owner, address spender, uint256 requestedAllowance, uint256 availableAllowance, address tokenAddress);

    /// @notice Thrown when the token approval operation fails.
    /// @param owner The address of the token owner.
    /// @param spender The address of the spender.
    /// @param amount The amount of tokens attempted to be approved.
    /// @param tokenAddress Address of the token.
    error TokenApproveFailed(address owner, address spender, uint256 amount, address tokenAddress);
    
    /// @notice Thrown when a token transfer fails.
    /// @param owner The address of the token owner.
    /// @param recipient The address of the recipient to whom tokens were transferred.
    /// @param amount The amount of tokens attempted to be transferred.
    /// @param tokenAddress Address of the token.
    error TokenTransferFailed(address owner, address recipient, uint256 amount, address tokenAddress);
}
