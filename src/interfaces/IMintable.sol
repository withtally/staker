// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @title IMintable
/// @author [ScopeLift](https://scopelift.co)
/// @notice Interface for contracts that can mint tokens to a specified address.
interface IMintable {
  /// @notice Mints new tokens to a specified address.
  /// @param _to The address that will receive the newly minted tokens.
  /// @param _amount The quantity of tokens to mint.
  function mint(address _to, uint256 _amount) external;
}
