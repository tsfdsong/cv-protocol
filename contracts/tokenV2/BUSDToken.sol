// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BUSDToken is ERC20, Ownable {
    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {
        _mint(msg.sender, 1000 * (10**uint256(decimals())));
    }

    /**
     * @dev allow owner to mint
     * @param _to mint token to address
     * @param _amount amount of ALPA to mint
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
