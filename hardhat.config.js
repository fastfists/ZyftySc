/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('solidity-coverage')
require("@nomiclabs/hardhat-waffle");
module.exports = {
    solidity: {
        version: "0.8.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    paths: {
        sources: "./contracts/",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
};
