pragma solidity ^0.8.1;

import "contracts/Lien/Lien.sol";

contract ParametricLien is Lien {

    uint256 lastUpdated;
    uint256 valuePer;
    uint256 period;
    uint256 start;

    constructor(address lienProvider,
                address assetType,
                uint256 startTime,
                uint256 initialValue,
                uint256 valuePerPeriod,
                uint256 _period) Lien(lienProvider, initialValue, assetType) { 

        start = startTime;
        if (start == 0) {
            start = block.timestamp;
        }
        lastUpdated = block.timestamp;
        valuePer = valuePerPeriod;
        period = _period;
    }

    function update() public virtual override {
        // Finds the total number of periods from start date
        uint256 totalPeriods = (start - block.timestamp) / period;
        uint256 updatedPeriods = (block.timestamp - lastUpdated) / period;
        increaseLien((totalPeriods - updatedPeriods)*valuePer);
        lastUpdated = block.timestamp;
    }

}
