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
  networks: {
        acalaTest: {
            url: "https://tc7-eth.aca-dev.network",
            chainId: 595,
            // Development built-in default deployment account
            accounts: ["0xa872f6cbd25a0e04a08b1e21098017a9e6194d101d75e13111f71410c59cd57f"]
      },
      matic: {
          url: "https://rpc-mumbai.maticvigil.com",
          accounts: ["46e0483c6cb7a3b10d643a4ecc643633b5c89f73756d7921511fa2ae3bb8040e", "29784bc06418dcf832968aba1f4580b5c96b32789098e60ac1f41a698c9c3086", "4a9241c5e34cbb3605e69fb781b7391d799de131cdc8ba0c133076789f4f8933"]
      }
  }
};
