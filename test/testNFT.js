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
        this.LIEN_FACTORY = await hre.ethers.getContractFactory("Lien");
        [this.owner, this.lien1P, this.lien2P] = await ethers.getSigners();

        this.tokenBalance = 50;
        this.id = 1;
        this.idOther = 2;
        this.lien1Val = 10;
        this.otherLienValue = 5;

        this.nft = await NFT_FACTORY.deploy(this.owner.address);
        this.token = await TOKEN_FACTORY.deploy(this.owner.address, this.lien1P.address, this.lien2P.address, this.tokenBalance);

        this.lien1 = await this.LIEN_FACTORY.deploy(this.lien1P.address, this.lien1Val, this.token.address)
        this.lien2 = await this.LIEN_FACTORY.deploy(this.lien1P.address, this.lien1Val, this.token.address)

        let metadataURI = "cid/test.json";

        await this.nft.connect(this.owner).mint(
            this.owner.address,
            metadataURI,
            this.lien1.address
        );

        await this.nft.connect(this.owner).mint(
            this.owner.address,
            metadataURI,
            this.lien2.address
        );

        this.p1Conn = this.nft.connect(this.lien1P);
        this.p2Conn = this.nft.connect(this.lien2P);
        this.ownerConn = this.nft.connect(this.owner);

        // Lets not worry about token allowances
        await this.token.connect(this.owner).approve(this.nft.address, this.tokenBalance*2);
    });

    it("Expects primary lien to exist", async function() {
        expect(await this.ownerConn.lien(this.id)).to.equal(this.lien1.address);
    });

    it("Increases the reseves", async function() {
        const amount = 20;
        // Add tokens into the main NFT
        await this.ownerConn.increaseReserve(this.id, amount);
        // Add tokens into the other NFT
        await this.ownerConn.increaseReserve(this.idOther, amount);

        expect(await this.ownerConn.getReserve(this.id)).to.equal(amount);
        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance - amount*2);
    });

    it("Redeems from the reserves", async function() {
        const amount = 20;
        expect(await this.ownerConn.getReserve(this.id)).to.equal(amount);
        await this.ownerConn.redeemReserve(this.id, amount/2);
        expect(await this.ownerConn.getReserve(this.id)).to.equal(amount/2);

        // Ensure the tokens got transfered to the owner
        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance - (amount/2 + amount));

        // Only the owner can redeem from reserves
        await expect(this.p1Conn.redeemReserve(this.id, amount/2)).to.be.reverted;

        // Does not overdraft
        expect(await this.token.balanceOf(this.nft.address)).to.equal(amount + amount/2);
        await this.ownerConn.redeemReserve(this.id, amount);
        expect(await this.ownerConn.getReserve(this.id)).to.equal(0);

        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance - amount);

        await this.ownerConn.redeemReserve(this.idOther, amount);
        expect(await this.token.balanceOf(this.owner.address)).to.equal(this.tokenBalance);
    });

    it("Pays assets off with reserves", async function() {
        // Have 1 lien to pay with value 10
        const amountToPay = 10;
        await this.ownerConn.increaseReserve(this.id, amountToPay);

        // Pay of secondry lien that has value 5, pays the full amount
        await this.ownerConn.payLienFull(this.id);

        const l = this.LIEN_FACTORY.attach(this.ownerConn.lien(this.id));
        expect(await l.balanceView()).to.equal(0);
        expect(await this.ownerConn.getReserve(this.id)).to.equal(0);
    });

    it("Destroys NFTs", async function() {
        await this.ownerConn.destroyNFT(this.id);
        expect(await this.ownerConn.lien(this.id)).to.equal("0x0000000000000000000000000000000000000000");
    });
});
