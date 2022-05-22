const { expect } = require("chai");
const { ethers } = require("hardhat");

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

// Tests should be ran on localhost test network
// Run command `npx hardhat test --network localhost` to test this code
describe("Lien Contracts", function () {

    beforeEach(async function() { 

        const LIEN_FACTORY = await hre.ethers.getContractFactory("Lien");
        const PARAMETRIC_LIEN_FACTORY = await hre.ethers.getContractFactory("ParametricLien");
        const TOKEN_FACTORY = await hre.ethers.getContractFactory("TestToken");

        [this.buyer, this.provider, this.ot] = await ethers.getSigners();

        this.tokenBalance = 50;
        this.lienValue = 10;
        this.period = 30; // Every 30 seconds

        this.token = await TOKEN_FACTORY.deploy(this.ot.address, this.buyer.address, this.provider.address);
        this.lienStatic = await LIEN_FACTORY.deploy(this.provider.address, this.lienValue, this.token.address);
        this.lienParametric = await PARAMETRIC_LIEN_FACTORY.deploy(
            this.provider.address,
            this.token.address,
            0,
            this.lienValue,
            this.period
        );


        this.buyerStatic = this.lienStatic.connect(this.buyer);
    });

    it("Static lean finishes successful", async function() {
        expect(await this.lienStatic.balance()).to.equal(this.lienValue);

        // Lien is given full allowance 
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.tokenBalance);
        await this.buyerStatic.pay(this.lienValue/2)

        // Balance should be half left and sent to user
        expect(await this.lienStatic.balance()).to.equal(this.lienValue/2);
        expect(await this.token.balanceOf(this.provider.address)).to.equal(this.tokenBalance + this.lienValue/2);
        // Rest of the value paid off
        await this.buyerStatic.pay(this.lienValue/2)
        expect(await this.lienStatic.balance()).to.equal(0);

    });

    it("Static lean does not overdraft when paid with non-zero balance", async function() {
        // Should work from previous test
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.tokenBalance);
        await this.buyerStatic.pay(this.lienValue);
        expect(await this.lienStatic.balance()).to.equal(0);

        // Ensure balance does not go negative, and no tokens are transfered
        const balanceBefore = await this.token.balanceOf(this.buyer.address);
        // Pay off the rest of my tokens
        await this.buyerStatic.pay(this.tokenBalance - this.lienValue);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(balanceBefore);
        expect(await this.lienStatic.balance()).to.equal(0);
    });

    it("Static leans with failed transaction", async function() {
        expect(await this.lienStatic.balance()).to.equal(this.lienValue);

        // Lien is given half the expected allowance 
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.lienValue/2);
        await expect(this.buyerStatic.pay(this.lienValue)).to.be.reverted;

        // Balance should remain the same after transaction
        expect(await this.lienStatic.balance()).to.equal(this.lienValue);
    });

});
