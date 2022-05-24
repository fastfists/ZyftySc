pragma solidity ^0.8.1;

interface ILien {
    /**
     * @dev Returns the main Lien Provider of this Lien
     */
    function lienProvider() external view returns(address);

    /**
     * @dev Sets `lienProvider()` to `newLienProvider`
     */
    function setLienProvider(address newLienProvider) external;

    /**
     * @dev Pays `amount` tokens of the default asset to the `lienProvider()`
     */
    function pay(uint256 amount) external returns(uint256);

    /**
     * @dev Updates the `balance()` of the lien, this is called
     *      to update temporal logic or any other purposes that
     *      are static. Update uses increaseLien() and decreaseLien()
     *      to change the value.
     */
    function update() external;

    /**
     * @dev Returns the asset type of the Lien
     */
    function asset() external view returns(address);

    /**
     * @dev Returns the current amount of debt that is in the lien,
     *      WARNING, this is not ensured to be up to date, unless an
     *      `update()` is called before. The value is typically lower
     *      than reality.
     */
    function balance() external view returns(uint256);
}
