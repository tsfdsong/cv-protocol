import { expect, use } from "chai";
import { deployContract, deployMockContract, MockProvider, solidity } from "ethereum-waffle";
import { Contract, ContractFactory } from "ethers";
import ICVNft = require("../build/waffle/ICVNft.json");
import CVStaking = require("../build/waffle/CVStaking.json");
import MultipleSignaturesAccount = require("../build/waffle/MultipleSignaturesAccount.json");
import CVCToken = require("../build/waffle/CVCToken.json");

use(solidity);

describe("CVStaking", () => {
  const [owner, user1] = new MockProvider().getWallets();
  let nft: Contract;
  let staking: Contract;
  let platform: Contract;
  let cvc: Contract;

  async function mockNftFunc(_nft: Contract) {
    await _nft.mock.powerOf.returns(1);
    await _nft.mock.addBlindCount.returns();
    await _nft.mock.ownerOf.returns(owner.address);
    await _nft.mock.transferFrom.returns();
    await _nft.mock.getApproved.returns(staking.address);
    await _nft.mock.isApprovedForAll.returns(true);
  }

  beforeEach(async () => {
    nft = await deployMockContract(owner, ICVNft.abi);
    const contractFactory = new ContractFactory(CVStaking.abi, CVStaking.bytecode, owner)
    staking = await contractFactory.deploy(nft.address);
    await mockNftFunc(nft);
    platform = await deployContract(owner, MultipleSignaturesAccount, ["Platform Multisignature Contract"]);
    cvc = await deployContract(owner, CVCToken, ["CVC TOKEN", "CVC"]);
    const amount = "100000000000000000000000000";
    await cvc.mint(platform.address, amount);
    await platform.approve(cvc.address, staking.address, amount);
    await staking.setPlatformAccountAddress(platform.address);
    await staking.setCVCAddress(cvc.address);
    await staking.setBoxIncomePerBlock(100);
    await staking.setCvcIncomePerBlock(20);
  });

  it("has correct power", async () => {
    expect(await nft.powerOf(1)).to.eq(1);
  });

  it("has correct stake", async () => {
    await expect(staking.stake(nft.address, 1)).to.emit(staking, "Stake").withArgs(owner.address, nft.address, 1, 1);
    expect(await staking.cvcBalanceOf(owner.address)).to.eq(0)
  });

  it("has correct redeem", async () => {
    await staking.stake(nft.address, 1);
    await expect(staking.redeem(nft.address, 1)).to.emit(staking, "Redeem").withArgs(owner.address, nft.address, 1, 1);
  });

  it("has correct settleAllUsersIncome", async () => {
    await staking.stake(nft.address, 1);
    await expect(staking.settleAllUsersIncome(100)).to.emit(staking, "Settle").withArgs(100, 72, 73, 1);
    expect(await staking.boxBalanceOf(owner.address)).to.eq(100);
    expect(await staking.cvcBalanceOf(owner.address)).to.eq(20);
  });

  it("has correct claimBox", async () => {
    await staking.stake(nft.address, 1);
    await staking.settleAllUsersIncome(100);
    await staking.setBoxPrice(1, 100)
    await staking.setBoxPrice(2, 200)
    await staking.setBoxPrice(3, 300)
    expect(await staking.claimBox(1, 1));
  });
});
