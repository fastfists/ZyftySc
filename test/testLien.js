const { expect } = require("chai");
const { ethers } = require("hardhat");
const { calcEthereumTransactionParams } = require("@acala-network/eth-providers")

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

const txFeePerGas = '199999946752';
const storageByteDeposit = '100000000000000';

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
        this.period = 5; // Every 5 seconds

        const blockNumber = await ethers.provider.getBlockNumber();
        const ethParams = calcEthereumTransactionParams({
            gasLimit: '21000010',
            validUntil: (blockNumber + 100000).toString(),
            storageLimit: '640010',
            txFeePerGas,
            storageByteDeposit
        });


// const LienAddr ="0x758215B538aF72ED0eBF6fCD353119146c8B7Ef9"
// const TokenAddr ="0x5489a56DcCa0Dcf5b33cE430354c4DA73Cd00E7f"

        this.token = await TOKEN_FACTORY.deploy(this.ot.address, this.provider.address, this.buyer.address, this.tokenBalance, {
                gasPrice: ethParams.txGasPrice,
                gasLimit: ethParams.txGasLimit,
                });
        this.lienStatic = await LIEN_FACTORY.deploy(this.provider.address, this.lienValue, this.token.address, {
                gasPrice: ethParams.txGasPrice,
                gasLimit: ethParams.txGasLimit,
                });
        // this.token = await TOKEN_FACTORY.attach(TokenAddr);
        // this.lienStatic = await LIEN_FACTORY.attach(LienAddr);

        await this.lienStatic.deployed();
        this.lienParametric = await PARAMETRIC_LIEN_FACTORY.deploy(
            this.provider.address,
            this.token.address,
            0,
            0,
            this.lienValue,
            this.period, {
                gasPrice: ethParams.txGasPrice,
                gasLimit: ethParams.txGasLimit,
                }
        );

        this.buyerStatic = this.lienStatic.connect(this.buyer);
        this.buyerParametric = this.lienParametric.connect(this.buyer);
    });

    it("Static lien finishes successful", async function() {
        expect(await this.lienStatic.balanceView()).to.equal(this.lienValue);

        // Lien is given full allowance 
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.tokenBalance);
        await this.buyerStatic.pay(this.lienValue/2)

        // Balance should be half left and sent to user
        expect(await this.lienStatic.balanceView()).to.equal(this.lienValue/2);
        expect(await this.token.balanceOf(this.provider.address)).to.equal(this.tokenBalance + this.lienValue/2);
        // Rest of the value paid off
        await this.buyerStatic.pay(this.lienValue/2)
        expect(await this.lienStatic.balanceView()).to.equal(0);

    });

    it("Static lien does not overdraft when paid with non-zero balance", async function() {
        // Should work from previous test
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.tokenBalance);
        await this.buyerStatic.pay(this.lienValue);
        expect(await this.lienStatic.balanceView()).to.equal(0);

        // Ensure balance does not go negative, and no tokens are transfered
        const balanceBefore = await this.token.balanceOf(this.buyer.address);
        // Pay off the rest of my tokens
        await this.buyerStatic.pay(this.tokenBalance - this.lienValue);
        expect(await this.token.balanceOf(this.buyer.address)).to.equal(balanceBefore);
        expect(await this.lienStatic.balanceView()).to.equal(0);
    });

    it("Static liens with failed transaction", async function() {
        expect(await this.lienStatic.balanceView()).to.equal(this.lienValue);

        // Lien is given half the expected allowance 
        await this.token.connect(this.buyer).approve(this.lienStatic.address, this.lienValue/2);
        await expect(this.buyerStatic.pay(this.lienValue)).to.be.reverted;

        // Balance should remain the same after transaction
        expect(await this.lienStatic.balanceView()).to.equal(this.lienValue);
    });

    it("Tests parametric lien updates value", async function() {
        expect(await this.buyerParametric.balanceView()).to.equal(0);
        await sleep((this.period)*1000);
        // Balance should not automatically be updated
        expect(await this.buyerParametric.balanceView()).to.equal(0);
        let x = await this.buyerParametric.update();
        await x.wait();
        expect(await this.buyerParametric.balanceView()).to.equal(this.lienValue);
    });

    it("Tests parametric lien updates on pay", async function() {
        expect(await this.lienParametric.balanceView()).to.equal(0);
        await this.token.connect(this.buyer).approve(this.lienParametric.address, this.tokenBalance);
        // wait 2 periods, value should be lienValue*2
        await sleep(this.period*1000);
        await sleep(this.period*1000);
        await this.buyerParametric.pay(this.tokenBalance);

        expect(await this.token.balanceOf(this.buyer.address)).to.equal(this.tokenBalance - this.lienValue*2);
    });

});
