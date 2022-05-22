pragma solidity ^0.8.1;

import "contracts/Lien/ILien.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lien is ILien {

    address private provider;
    address private tokenAddr;
    uint256 private value;

    constructor(address _provider, uint256 _value, address assetType) {
        provider = _provider;
        tokenAddr = assetType;
        value = _value;
    }

    /*
     * @dev Pays `amount` tokens of the default asset to the `lienProvider()`
     *      on payment update() is called 
     */
    function pay(uint256 amount) public virtual override {
        update();
        IERC20 token = IERC20(asset());
        if (amount >= value) {
            // prevent overflow
            amount = value;
        }
        token.transferFrom(msg.sender, lienProvider(), amount);
        decreaseLien(amount);
    }
    /*
     * @dev Updates the `balance()` of the lien, this is called
     *      to update temporal logic or any other purposes that
     *      aren't static
     */
    function update() public virtual override {
        // No update for static Liens
    }

    /**
     * @dev Sets `lienProvider()` to `newProvider``
     */
    function setLienProvider(address newProvider) public virtual override {
        provider = newProvider;
    }

    /**
     * @dev Returns the main Lien Provider of this Lien
     */
    function lienProvider() public view virtual override returns(address) {
        return provider;
    }

    /*
     * @dev Returns the current amount of debt that is in the lien,
     *      WARNING, this is not ensured to be up to date, unless an
     *      `update()` is called before. The value is typically lower
     *      than reality.
     */
    function balance() public virtual override view returns(uint256) {
        return value;
    }

    function asset() public virtual override view returns(address) {
        return tokenAddr;
    }

    /**
     * @dev Increases the value of the lien by `amount`, meant to be called by subclasses
     */
    function increaseLien(uint256 amount) internal {
        value += amount;
    }

    /**
     * @dev Decreases the value of the lien by `amount`, meant to be called by subclasses
     *      if value, will become negative as a result of this, it returns the remainder.
     */
    function decreaseLien(uint256 amount) internal returns(uint256 remainder) {
        remainder = 0;
        if (amount >= value) {
            remainder = amount - value;
        }
        value -= amount;
    }

}
