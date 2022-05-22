pragma solidity ^0.8.1;

import "contracts/Lien/Lien.sol";

contract ParametricLien is Lien {

    uint256 lastUpdated;
    uint256 valuePer;
    uint256 period;

    constructor(address lienProvider,
                address assetType,
                uint256 initialValue,
                uint256 valuePerPeriod,
                uint256 _period) Lien(lienProvider, initialValue, assetType) { 
        lastUpdated = block.timestamp;
        valuePer = valuePerPeriod;
        period = _period;
    }

    function update() public virtual override {
        uint256 periods = (block.timestamp - lastUpdated)/period;
        increaseLien(periods*valuePer);
    }

}
