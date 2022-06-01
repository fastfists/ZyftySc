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

    it("Expects primay lien lien ID 0", async function() {
        expect(await this.ownerConn.getLien(this.id, 0)).to.equal(this.lien1.address);
    });

    it("Adds a Lien", async function() {
        // ensure that the most recent proposal is used
        let lien2      = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);
        let randomLien = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);

        await this.ownerConn.proposeLien(this.id, randomLien.address);
        await this.ownerConn.proposeLien(this.id, lien2.address);

        // Can't accept this lien
        await expect(this.p2Conn.acceptLien(this.id, randomLien.address)).to.be.reverted;
        await expect(this.p2Conn.acceptLien(this.id, lien2.address))
          .to.emit(this.nft, 'LienAdded')
          .withArgs(this.id, 1, lien2.address);

        expect(await this.nft.getLien(this.id, 1)).to.equal(lien2.address);
    });

    it("Limits liens to 4", async function() {
        // Should have 2 liens right now
        let lien3 = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);
        let lien4 = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);
        let lien5 = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);

        await this.ownerConn.proposeLien(this.id, lien3.address);
        await this.p2Conn.acceptLien(this.id, lien3.address);

        await this.ownerConn.proposeLien(this.id, lien4.address);
        await this.p2Conn.acceptLien(this.id, lien4.address);

        await expect(this.ownerConn.proposeLien(this.id, lien5.address)).to.be.reverted;
        // await this.p2Conn.acceptLien(this.id, lien5.address);
    });

    it("Removes liens", async function() {
        await expect(this.p2Conn.removeLien(this.id, 0)).to.be.reverted;
        expect(await this.p2Conn.getLien(this.id, 2)).to.not.equal(0);
        await this.p2Conn.removeLien(this.id, 2); // removes lien 3
        expect(await this.p2Conn.getLien(this.id, 2)).to.equal("0x0000000000000000000000000000000000000000");

        await this.p2Conn.removeLien(this.id, 3); // removes lien 4
        expect(await this.p2Conn.getLien(this.id, 3)).to.equal("0x0000000000000000000000000000000000000000");
    });

    it("Adds liens in lowest order", async function() {
        let lien5 = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, this.token.address);
        await this.ownerConn.proposeLien(this.id, lien5.address);
        await this.p2Conn.acceptLien(this.id, lien5.address);
        // should insert in position of lien3
        expect(await this.p2Conn.getLien(this.id, 2)).to.equal(lien5.address);
    });

    it("Enforces Liens of the same asset", async function() {
        const TOKEN_FACTORY = await ethers.getContractFactory("TestToken");
        let token2 = await TOKEN_FACTORY.deploy(this.owner.address, this.lien1P.address, this.lien2P.address, this.tokenBalance);
        // create lien with another token deployed
        let lien = await this.LIEN_FACTORY.deploy(this.lien2P.address, this.otherLienValue, token2.address);

        await expect(this.ownerConn.proposeLien(this.id, lien.address)).to.be
            .revertedWith("The asset type of this lien must be the asset type of the contract");
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
        // Have 2 leans with value 5 and primary with value 10
        const amountToPay = 20;
        await this.ownerConn.increaseReserve(this.id, amountToPay);

        // Pay of secondry lien that has value 5, pays the full amount
        await this.ownerConn.payLienFull(this.id, 1);

        const lienAddr = await this.ownerConn.getLien(this.id, 1)
        const l = this.LIEN_FACTORY.attach(lienAddr);
        expect(await l.balanceView()).to.equal(0);

        expect(await this.ownerConn.getReserve(this.id)).to.equal(15);
        await this.ownerConn.balanceAccounts(this.id);

        expect(await this.ownerConn.getReserve(this.id)).to.equal(0);
    });

    it("Destroys NFTs", async function() {
        await this.ownerConn.destroyNFT(this.id);
        expect(await this.ownerConn.getLien(this.id, 0)).to.equal("0x0000000000000000000000000000000000000000");
        expect(await this.ownerConn.getLien(this.id, 1)).to.equal("0x0000000000000000000000000000000000000000");
        expect(await this.ownerConn.getLien(this.id, 2)).to.equal("0x0000000000000000000000000000000000000000");
        expect(await this.ownerConn.getLien(this.id, 3)).to.equal("0x0000000000000000000000000000000000000000");
    });

});
