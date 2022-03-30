const { expect } = require("chai");
const { ethers } = require("hardhat");

// Tests should be ran on localhost test network
// Run command `npx hardhat test --network localhost` to test this code
describe("RealEstateEscrow", function () {

   beforeEach(async function() { 
        const ESCROW_FACTORY = await ethers.getContractFactory("RealestateEscrow");
        const NFT_FACTORY = await hre.ethers.getContractFactory("RealestateNFT");

        this.escrow = await ESCROW_FACTORY.deploy();
        resp = await this.escrow.deployed();
        this.nftAddr = await this.escrow.nft();
        this.nft = NFT_FACTORY.attach(this.nftAddr);

   });

    it("Creates an NFT, and sells it", async function() {
        const [owner, signer1] = await ethers.getSigners();

        const metadataURI = "cid/test.json";
        const threshold = ethers.utils.parseEther('500');
        const sellingPrice = ethers.utils.parseEther('500');

        expect(await this.nft.balanceOf(signer1.address)).to.equal(0);
        // Create NFT, and should be owned by the contract
        const id = 1;
        var resp = await this.escrow.newProperty(metadataURI, threshold);
        await resp.wait();
        expect(await this.nft.ownerOf(id)).to.equal(this.escrow.address);

        resp = await this.escrow.listProperty(id, sellingPrice);
        await resp.wait();

        var a = await this.escrow.getProperty(id);
        expect(a.price).to.equal(sellingPrice);

        // This buy should fail
        var conn = this.escrow.connect(signer1);
        await expect(conn.buyProperty(id)).to.be.reverted;

        resp = await conn.buyProperty(id, {value: sellingPrice})
        await resp.wait();

        expect(await this.nft.balanceOf(signer1.address)).to.equal(1);
        expect((await this.nft.ownerOf(id))).to.equal(signer1.address);
        a = await this.escrow.getProperty(id);
    });

    it("Makes a property exceed its lean limit", async function() {
        const [owner, signer1] = await ethers.getSigners();

    });
});
