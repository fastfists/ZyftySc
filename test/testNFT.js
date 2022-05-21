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
        const NFT_FACTORY = await hre.ethers.getContractFactory("ZyftyNFT");

        [this.owner, this.lien1P, this.lien2P] = await ethers.getSigners();

        this.tokenBalance = 50;

        this.nft = await NFT_FACTORY.deploy(this.owner.address);
        this.token = await TOKEN_FACTORY.deploy(this.owner.address, this.lien1P.address, this.lien2P.address);
        this.price = 10;

        this.id = 1;
        metadataURI = "cid/test.json";
        await this.nft.connect(this.owner).mint(
            this.owner.address,
            metadataURI,
            this.lien1P.address,
            this.token.address,
        );

        this.p1Conn = this.nft.connect(this.lien1P);
        this.p2Conn = this.nft.connect(this.lien2P);
        this.ownerConn = this.nft.connect(this.owner);

        await this.token.connect(this.owner).approve(this.nft.address, this.tokenBalance);
    });

    it("Adds debt to a lien", async function() {
        this.lien1Val = 10;
        await this.p1Conn.increaseLien(this.id, 0, this.lien1Val);
        await expect(this.p2Conn.increaseLien(this.id, 0, this.lien1Val)).to.be.reverted;
        const l = await this.nft.getLien(this.id, 0);
        expect(l.value).to.equal(this.lien1Val);
    });

    it("Pays off lien debt", async function() {
        // Test against double spend
        const balBefore = await this.token.balanceOf(this.owner.address);
        await this.ownerConn.payLien(
            this.id,
            0,
            this.lien1Val / 2,
        );
        await this.ownerConn.balanceAccounts(this.id);
        let l = await this.nft.getLien(this.id, 0);

        let val = await this.token.balanceOf(this.owner.address);
        expect(val).to.equal(balBefore -this.lien1Val / 2);

        expect(l.value).to.equal(this.lien1Val/2);
        await this.ownerConn.payLien(
            this.id,
            0,
            this.lien1Val / 2
        );
        await this.ownerConn.balanceAccounts(this.id);


        val = await this.token.balanceOf(this.owner.address);
        expect(val).to.equal(balBefore - this.lien1Val);
        l = await this.nft.getLien(this.id, 1);
        expect(l.value).to.equal(0);
    });

    it("Static debt", async function() {
        this.lien2Val = 20;
        await this.ownerConn.addLien(this.id, this.token.address, this.lien2Val, this.lien2P.address, false);
        await expect(this.p2Conn.increaseLien(this.id, 1, 20)).to.be.reverted;
        await this.ownerConn.payLien(
            this.id,
            1,
            this.lien2Val
        );
        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance - this.lien1Val - this.lien2Val);
    });

    it("Has a 0.5% minting fee", async function() {
    });

});
