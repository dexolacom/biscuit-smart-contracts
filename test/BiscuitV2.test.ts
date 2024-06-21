import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { BiscuitV1, BiscuitV2, PortfolioManager, SignatureHelper } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("BiscuitV2", function () {
    let biscuitV2: BiscuitV2;
    let signatureHelper: SignatureHelper;
    let usdtToken: Contract;
    let owner: HardhatEthersSigner;

    async function deployBiscuitV2() {
        const [owner, user1] = await ethers.getSigners();

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

        const biscuitV2 = await (await ethers.getContractFactory("BiscuitV2")).deploy();
        const signatureHelper = await (await ethers.getContractFactory("SignatureHelper")).deploy();
        
        return { biscuitV2, signatureHelper, usdtToken, owner };
    }

    beforeEach("Init test environment", async () => {
        const fixture = await loadFixture(deployBiscuitV2);
        biscuitV2 = fixture.biscuitV2;
        signatureHelper = fixture.signatureHelper;
        usdtToken = fixture.usdtToken;
        owner = fixture.owner;
    });

    it.only("Should be swap token during mint and burn", async () => {
        const tokenOut = "0x00aF37A629dB89c37851921E79A9c024DAD0Ef8A";
        const router = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E";
        const fee = 3000;
        const amountToken = ethers.parseUnits("100", 6);

        await usdtToken.mint(amountToken);
        await usdtToken.approve(biscuitV2.target, amountToken);

        const swap = await signatureHelper.generateSwapSignature(usdtToken.target, tokenOut, fee, biscuitV2.target, amountToken, 0, 0);
        const token = await signatureHelper.generateTransferFromSignature(owner.address, biscuitV2.target, amountToken);
        const approve = await signatureHelper.generateApproveSignature(router, amountToken);
        console.log(swap.signature);
        const mintParams = {
            to: owner.address,
            targets: [usdtToken.target, usdtToken.target, router], 
            values: [0, 0, 0],
            signatures: [token.signature, approve.signature, swap.signature],
            calldatas: [token.callData, approve.callData, swap.callData]
        };

        const burnParams = {
            targets: [],
            values: [],
            signatures: [],
            calldatas: []
        };

        await biscuitV2.mint(mintParams, burnParams);
        console.log(await usdtToken.balanceOf(biscuitV2.target));
    });
});
