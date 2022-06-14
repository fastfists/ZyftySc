const { expect } = require("chai");
const { ethers } = require("hardhat");

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

// Tests should be ran on localhost test network
// Run command `npx hardhat test --network localhost` to test this code
describe("ZyftySalesContract", function () {

    // Define constants, that could be redefined in other tests
    before(async function() {
        this.tokenBalance = 300;
        this.time = 5;
        this.price = 200;
        this.id = 1;
        this.LIEN_FACTORY = await hre.ethers.getContractFactory("Lien");
        this.lienVal = 0;

        [this.seller, this.buyer, this.lien1P, this.zyftyAdmin] = await ethers.getSigners();
    });

    beforeEach(async function() { 
        const ESCROW_FACTORY = await ethers.getContractFactory("ZyftySalesContract");
        const TOKEN_FACTORY = await ethers.getContractFactory("TestToken");
        const NFT_FACTORY = await hre.ethers.getContractFactory("ZyftyNFT");



        this.escrow = await ESCROW_FACTORY.deploy(this.zyftyAdmin.address);
        this.nft = await NFT_FACTORY.deploy(this.escrow.address);
        this.token = await TOKEN_FACTORY.deploy(this.seller.address, this.buyer.address, this.lien1P.address, this.tokenBalance);

        metadataURI = "cid/test.json";

        this.lien = await this.LIEN_FACTORY.deploy(this.lien1P.address, this.lienVal, this.token.address)

        await this.nft.connect(this.seller).mint(
            this.seller.address,
            metadataURI,
            this.lien.address
        );

        await this.nft.connect(this.seller).approve(this.escrow.address, this.id);

        this.buyerConn = this.escrow.connect(this.buyer);
        this.sellerConn = this.escrow.connect(this.seller);

        await this.sellerConn.sellProperty(
            this.nft.address, 
            this.id,  // tokenID
            this.price,  // price
            this.time, //time
        );

        await this.token.connect(this.buyer).approve(this.escrow.address, this.price);
    });

    it("Executes escrow succesfully", async function() {
        expect(await this.nft.ownerOf(this.id)).to.equal(this.escrow.address);
        expect(await this.nft.balanceOf(this.buyer.address)).to.equal(0);

        await this.buyerConn.buyProperty(this.id)
        expect(await this.token.balanceOf(this.escrow.address)).to.equal(this.price);

        expect(await this.nft.ownerOf(this.id)).to.equal(this.escrow.address);
        await this.sellerConn.execute(this.id);

        const fee = this.price/200;
        expect(await this.token.balanceOf(this.seller.address)).to.equal(this.price - fee + this.tokenBalance);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(this.tokenBalance - this.price);

        expect(await this.nft.balanceOf(this.seller.address)).to.equal(0);
        expect(await this.nft.balanceOf(this.buyer.address)).to.equal(1);
    });

    it("Reverts seller escrow", async function() {
        await expect(this.sellerConn.revertSeller(this.id)).to.be.reverted;
        await sleep(this.time*1000);
        // Ensure this fails
        await expect(this.buyerConn.revertSeller(this.id)).to.be.reverted;
        await this.sellerConn.revertSeller(this.id);
        expect(await this.nft.ownerOf(this.id)).to.equal(this.seller.address);

        await expect(this.sellerConn.execute()).to.be.reverted;

        const p = await this.escrow.getProperty(this.id);
        expect(p.state).to.equal(0); // 0 == DOESN'T Exist
    });

    it("Reverts buyer escrow", async function() {
        await this.buyerConn.buyProperty(this.id);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(this.tokenBalance - this.price);
        await expect(this.buyerConn.revertBuyer(this.id)).to.be.reverted;
        await sleep(this.time*1000);
        // Ensure this fails
        await expect(this.sellerConn.revertBuyer(this.id)).to.be.reverted;
        await this.buyerConn.revertBuyer(this.id);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(this.tokenBalance);

        const p = await this.escrow.getProperty(this.id);
        expect(p.state).to.equal(3); // 3 == CANCLED

        this.lienVal = 30; // For next test increase the lien value to a non zero number
    });

    it("Pays off primary lien account on Transfer", async function() {
        await this.buyerConn.buyProperty(this.id)

        await this.sellerConn.execute(this.id);

        const fee = this.price/200;
        expect(await this.token.balanceOf(this.seller.address)).to.equal(this.price - fee - this.lienVal + this.tokenBalance);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(this.tokenBalance - this.price);

        this.lienVal = this.price; // For the next testcase
    });

    it("Reverts execute when proceeds don't cover lien payments", async function() {
        await this.buyerConn.buyProperty(this.id)
        await expect(this.sellerConn.execute(this.id)).to.be.reverted;
    });

});
