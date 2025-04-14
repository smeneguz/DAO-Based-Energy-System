// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EnergyDAOToken
 * @dev Governance and utility token for the Energy Community DAO
 * Used for membership fees, energy trading, and governance voting
 */
contract EnergyDAOToken is ERC20, ERC20Burnable, Ownable {
    /**
     * @dev Constructor that mints initial supply to the contract creator
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens (in full units, not wei)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Allows the contract owner to mint new tokens
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Adds a decimal override to use 18 decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the address of the current owner
     */
    function getOwner() external view returns (address) {
        return owner();
    }

    /**
     * @dev Allows burning tokens from a specified account (if approved)
     * @param account The account to burn tokens from
     * @param amount The amount to burn
     */
    function burnFrom(address account, uint256 amount) public override {
        if (account == _msgSender()) {
            _burn(account, amount);
        } else {
            super.burnFrom(account, amount);
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     * Can be used to implement transfer restrictions if needed
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        // Additional transfer logic could be added here if needed
    }
}