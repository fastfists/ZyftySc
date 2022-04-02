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

        [this.owner, this.signer1] = await ethers.getSigners();
        this.id = 1;

        metadataURI = "cid/test.json";
        this.threshold = ethers.utils.parseEther('8');
        this.sellingPrice = ethers.utils.parseEther('8');

        var resp = await this.escrow.newProperty(metadataURI, this.threshold);
        // await resp.wait();

        resp = await this.escrow.listProperty(this.id, this.sellingPrice);
        // await resp.wait();

        this.buyerConn = this.escrow.connect(this.signer1);
        this.ownerConn = this.escrow.connect(this.owner);

        resp = await this.buyerConn.buyProperty(this.id, {value: this.sellingPrice})
        // await resp.wait();
   });

    it("Creates an NFT, and sells it", async function() {
        expect(await this.escrow.owner()).to.be.equal(this.owner.address);

        const metadataURI = "cid/test.json";
        const threshold = ethers.utils.parseEther('500');
        const sellingPrice = ethers.utils.parseEther('500');

        expect(await this.nft.balanceOf(this.signer1.address)).to.equal(1);
        // Create NFT, and should be owned by the contract
        const id = 2;
        var resp = await this.escrow.newProperty(metadataURI, threshold);
        // await resp.wait();
        expect(await this.nft.ownerOf(id)).to.equal(this.escrow.address);

        resp = await this.escrow.listProperty(id, sellingPrice);
        // await resp.wait();

        var a = await this.escrow.getProperty(id);
        expect(a.price).to.equal(sellingPrice);

        // This buy should fail
        await expect(this.buyerConn.buyProperty(id)).to.be.reverted;

        resp = await this.buyerConn.buyProperty(id, {value: sellingPrice})
        // await resp.wait();

        expect(await this.nft.balanceOf(this.signer1.address)).to.equal(2);
        expect((await this.nft.ownerOf(id))).to.equal(this.signer1.address);
        a = await this.escrow.getProperty(id);
    });

    it("Makes a property exceed its lean limit", async function() {
        expect(await this.escrow.owner()).to.be.equal(this.owner.address);

        var a = await this.escrow.getProperty(this.id);
        expect(a.lean1).to.equal(0);

        // Should not delete NFT
        resp = await this.ownerConn.changeLean(this.id, this.threshold);
        // await resp.wait();

        a = await this.escrow.getProperty(this.id);
        expect(a.lean1).to.equal(this.threshold);

        // Restrict others from accessing changeLean
        await expect(this.buyerConn.changeLean(this.id, this.threshold - 1)).to.be.reverted;

        // Now the NFT will be deleted, threshold has been exceeded
        // TODO, make this actually delete the NFT and move the debt to the owner
        await this.ownerConn.changeLean(this.id, 1);

        a = await this.escrow.getProperty(this.id);
        // 2 == PropertyState.DELETED
        expect(a.state).to.equal(2);
        // Should not exist, and get reverted
        expect(this.nft.ownerOf(this.id)).to.be.reverted;
    });

    it("Tests adding value from lean1 to lean2", async function() {
        var a = await this.escrow.getProperty(this.id);
        expect(a.lean1).to.equal(0);
        expect(a.lean2).to.equal(0);

        // Should fail
        await expect(this.buyerConn.proposeLean2Transfer(this.id, 1)).to.be.reverted;
        
        const val = ethers.utils.parseEther('4');
        await this.ownerConn.changeLean(this.id, val);

        await expect(this.buyerConn.proposeLean2Transfer(this.id, this.threshold)).to.be.reverted;
        await this.buyerConn.proposeLean2Transfer(this.id, val)
        a = await this.escrow.getProperty(this.id);

        // 1 == PropertyState.PENDING_LEAN2_ACCEPT
        expect(a.state).to.be.equal(1);
        expect(a.amountProposed).to.be.equal(val);
        expect(a.lean1).to.equal(val);
        expect(a.lean2).to.equal(0);

        await this.ownerConn.acceptLean2Transfer(this.id, val);
        a = await this.ownerConn.getProperty(this.id);
        expect(a.lean1).to.equal(0);
        expect(a.lean2).to.equal(val);
        expect(a.state).to.be.equal(0);
    });

    it("Tests adding value from lean1 to lean2, DENIED", async function() {
        var a = await this.escrow.getProperty(this.id);
        expect(a.lean1).to.equal(0);
        expect(a.lean2).to.equal(0);

        const val = ethers.utils.parseEther('4');
        await this.ownerConn.changeLean(this.id, val);

        await expect(this.buyerConn.proposeLean2Transfer(this.id, this.threshold)).to.be.reverted;
        await this.buyerConn.proposeLean2Transfer(this.id, val)
        a = await this.escrow.getProperty(this.id);

        // 1 == PropertyState.PENDING_LEAN2_ACCEPT
        expect(a.state).to.be.equal(1);
        expect(a.amountProposed).to.be.equal(val);
        expect(a.lean1).to.equal(val);
        expect(a.lean2).to.equal(0);

        await this.ownerConn.denyLean2Transfer(this.id);
        // a = await this.ownerConn.getProperty(this.id);
        // expect(a.lean1).to.equal(val);
        // expect(a.lean2).to.equal(0);
        // expect(a.state).to.be.equal(0);

    });
});
