import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { BiscuitV1, PortfolioManager } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("Biscuit", function () {
    let biscuitV1: BiscuitV1;
    let usdtToken: Contract;
    let wethToken: Contract;
    let flokiToken: Contract;
    let memeToken: Contract;
    let pepeToken: Contract;
    let shibaToken: Contract;
    let owner: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner;

    async function deployBiscuitV1() {
        const [owner, user1, user2] = await ethers.getSigners();

        const factory = "0x0227628f3F023bb0B980b67D528571c95c6DaC1c";
        const route = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E";

        const erc20Abi = [
            "function name() view returns (string)",
            "function symbol() view returns (string)",
            "function decimals() view returns (uint8)",
            "function totalSupply() view returns (uint256)",
            "function balanceOf(address owner) view returns (uint256)",
            "function approve(address spender, uint256 amount) returns (bool)",
            "function allowance(address owner, address spender) view returns (uint256)",
            "function transfer(address to, uint256 amount) returns (bool)",
            "function mint(uint256 amount) returns (bool)"
        ];

        const usdtToken = new ethers.Contract("0x04d0CaebCA219DAFBC394cD6e62b3181be29d1B3", erc20Abi, owner);
        const wethToken = new ethers.Contract("0xfff9976782d46cc05630d1f6ebab18b2324d6b14", erc20Abi, owner);
        const flokiToken = new ethers.Contract("0x00aF37A629dB89c37851921E79A9c024DAD0Ef8A", erc20Abi, owner);
        const memeToken = new ethers.Contract("0x86601ce1f386d35684f3D00Bb5914D83ABC28c20", erc20Abi, owner);
        const pepeToken = new ethers.Contract("0x4b14415148555d4d5c3D6F6c24b564953E6F6E13", erc20Abi, owner);
        const shibaToken = new ethers.Contract("0xC4b78b1cA6F90eCeBAdb2A1A2127814661A35200", erc20Abi, owner);

        const memePortfolio = [
            { token: flokiToken.target, share: 15_00 },
            { token: memeToken.target, share: 35_00 },
            { token: pepeToken.target, share: 25_00 },
            { token: shibaToken.target, share: 25_00 },
        ];

        const SwapLibrary = await (await ethers.getContractFactory("SwapLibrary")).deploy();
        const biscuitV1 = await(await ethers.getContractFactory("BiscuitV1", { libraries: { SwapLibrary } })).deploy(
            owner,
            factory,
            route,
            usdtToken.target,
            wethToken.target
        ) as BiscuitV1;
        const portfolioManager = await (await ethers.getContractFactory("PortfolioManager")).deploy(owner, biscuitV1.target) as PortfolioManager;
        await portfolioManager.addPortfolio(memePortfolio);
        await biscuitV1.setPortfolioManager(portfolioManager.target);

        return { biscuitV1, owner, user1, user2, usdtToken, wethToken, flokiToken, memeToken, pepeToken, shibaToken };
    }

    beforeEach("Init test environment", async () => {
        const fixture = await loadFixture(deployBiscuitV1);
        biscuitV1 = fixture.biscuitV1;
        owner = fixture.owner;
        user1 = fixture.user1;
        usdtToken = fixture.usdtToken;
        wethToken = fixture.wethToken;
        flokiToken = fixture.flokiToken;
        memeToken = fixture.memeToken;
        pepeToken = fixture.pepeToken;
        shibaToken = fixture.shibaToken;
    });


    it("Should correct buy and sell portfolio for USDT", async function () {
        const amountUSDT = ethers.parseUnits("100", 6);
        const oneToken = ethers.parseUnits("1", 18);
        const serviceFee = ethers.parseUnits("1", 6);

        await usdtToken.mint(amountUSDT);
        await usdtToken.approve(biscuitV1.target, amountUSDT);
        await biscuitV1.buyPortfolioERC20(1, amountUSDT, 0, 0);

        expect(await biscuitV1.balanceOf(owner.address)).to.eq(1);
        expect(await usdtToken.balanceOf(owner.address)).to.eq(0);
        expect(await usdtToken.balanceOf(biscuitV1.target)).to.eq(serviceFee);
        expect(await flokiToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await memeToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await pepeToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await shibaToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
    
        await biscuitV1.sellPortfolio(usdtToken.target, 1, 0, 0);

        expect(await biscuitV1.balanceOf(owner.address)).to.eq(0);
        expect(await usdtToken.balanceOf(owner.address)).to.eq(98406929); // equal 98 +- since service fee + default fee
        expect(await usdtToken.balanceOf(biscuitV1.target)).to.eq(serviceFee);
        expect(await flokiToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await memeToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await pepeToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await shibaToken.balanceOf(biscuitV1.target)).to.eq(0);
    });

    it("Should correct buy and sell portfolio for ETH", async function () {
        const amountETH = ethers.parseUnits("0.1", 18);
        const serviceFee = ethers.parseUnits("0.001", 18);
        const oneToken = ethers.parseUnits("1", 18);

        await biscuitV1.buyPortfolioETH(1, 0, 0, { value: amountETH });
        const ethBalanceBuyerAfterPurchased = await ethers.provider.getBalance(owner.address); 
        expect(await biscuitV1.balanceOf(owner.address)).to.eq(1);
        expect(await ethers.provider.getBalance(biscuitV1.target)).to.eq(serviceFee);
        expect(await flokiToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await memeToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await pepeToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);
        expect(await shibaToken.balanceOf(biscuitV1.target)).to.greaterThan(oneToken);

        await biscuitV1.sellPortfolio(wethToken.target, 1, 0, 0);

        expect(await biscuitV1.balanceOf(owner.address)).to.eq(0);
        expect(await ethers.provider.getBalance(owner.address)).to.greaterThan(ethBalanceBuyerAfterPurchased);
        expect(await ethers.provider.getBalance(biscuitV1.target)).to.eq(serviceFee);
        expect(await flokiToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await memeToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await pepeToken.balanceOf(biscuitV1.target)).to.eq(0);
        expect(await shibaToken.balanceOf(biscuitV1.target)).to.eq(0);
    });
});
