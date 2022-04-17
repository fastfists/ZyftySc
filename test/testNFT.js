const { expect } = require("chai");
const { ethers } = require("hardhat");

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

// Tests should be ran on localhost test network
// Run command `npx hardhat test --network localhost` to test this code
describe("RealEstateNFT", function () {

    before(async function() { 
        const TOKEN_FACTORY = await ethers.getContractFactory("TestToken");
        const NFT_FACTORY = await hre.ethers.getContractFactory("RealestateNFT");

        [this.owner, this.lean1P, this.lean2P] = await ethers.getSigners();

        this.tokenBalance = 50;

        this.nft = await NFT_FACTORY.deploy();
        this.token = await TOKEN_FACTORY.deploy(this.owner.address, this.lean1P.address, this.lean2P.address);
        this.price = 10;

        this.id = 1;
        metadataURI = "cid/test.json";
        await this.nft.connect(this.owner).mint(
            this.owner.address,
            metadataURI,
            this.lean1P.address,
            this.token.address,
        );

        this.p1Conn = this.nft.connect(this.lean1P);
        this.p2Conn = this.nft.connect(this.lean2P);
        this.ownerConn = this.nft.connect(this.owner);

        await this.token.connect(this.owner).approve(this.nft.address, this.tokenBalance);
    });

    it("Adds debt to a lean", async function() {
        this.lean1Val = 10;
        await this.p1Conn.increaseLean(this.id, 1, this.lean1Val);
        await expect(this.p2Conn.increaseLean(this.id, 1, this.lean1Val)).to.be.reverted;
        const l = await this.nft.getLean(this.id, 1);
        expect(l.value).to.equal(this.lean1Val);
    });

    it("Pays off lean debt", async function() {
        // Test against double spend
        await this.ownerConn.payLean(
            this.id,
            1,
            this.token.address,
            this.lean1Val / 2,
        );
        let l = await this.nft.getLean(this.id, 1);
        expect(l.value).to.equal(this.lean1Val/2);
        await this.ownerConn.payLean(
            this.id,
            1,
            this.token.address,
            this.lean1Val,
        );
        const val = await this.token.balanceOf(this.owner.address);
        expect(val).to.equal(this.tokenBalance - this.lean1Val);
        l = await this.nft.getLean(this.id, 1);
        expect(l.value).to.equal(0);
    });

    it("Static debt", async function() {
        this.lean2Val = 20;
        await this.ownerConn.addLean(this.id, this.lean2Val, this.lean2P.address, false, this.token.address);
        await expect(this.p2Conn.increaseLean(this.id, 2, 20)).to.be.reverted;
        await this.ownerConn.payLean(
            this.id,
            2,
            this.token.address,
            this.lean2Val
        );
        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance - this.lean1Val - this.lean2Val);
    });
});
