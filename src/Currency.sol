// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract Currency is ERC20, Ownable {
    constructor(address owner) {
        _initializeOwner(owner);
    }

    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "ARM0RY";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "$ARM0RY";
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
