//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SwapERC20 is ERC20Burnable {
    constructor() ERC20("SwapERC20", "SC") {}
}
