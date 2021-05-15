import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { Contract } from "ethers";
import MultipleSignaturesAccount = require("../build/waffle/MultipleSignaturesAccount.json");
import CVCToken = require("../build/waffle/CVCToken.json");

use(solidity);

describe("MultipleSignaturesAccount", () => {
  const [owner, user1] = new MockProvider().getWallets();
  let msAccount: Contract;
  let token: Contract;

  beforeEach(async () => {
    msAccount = await deployContract(owner, MultipleSignaturesAccount);
    token = await deployContract(owner, CVCToken, ["CVC Token", "CVC"]);
  });

  it("has correct name", async () => {
    expect(await token.name()).to.eq("CVC Token");
  });

  it("has correct symbol", async () => {
    expect(await token.symbol()).to.eq("CVC");
  });

  it("has correct decimal", async () => {
    expect(await token.decimals()).to.eq(18);
  });

  it("has correct initial supply of 0", async () => {
    expect(await token.totalSupply()).to.eq(0);
  });

  it("owner can mint", async () => {
    await expect(token.mint(msAccount.address, "1000"))
      .to.emit(token, "Transfer")
      .withArgs(
        "0x0000000000000000000000000000000000000000",
        msAccount.address,
        "1000"
      );
  });

  it("owner can add amin", async () => {
    expect(await msAccount.addAdmin(user1.address));
  });

  it("admin can applyWithdraw", async () => {
    await token.mint(msAccount.address, "1000")
    await msAccount.addAdmin(user1.address)
    const msAccountFromUser1 = msAccount.connect(user1);
    await expect(msAccountFromUser1.applyWithdraw(token.address, user1.address, "1000")).to.emit(token, "Transfer")
      .withArgs(
        msAccount.address,
        user1.address,
        "1000"
      );
  });

  it("other cannot mint", async () => {
    const tokenFromUser1 = token.connect(user1);

    await expect(tokenFromUser1.mint(user1.address, "1000")).to.be.reverted;
  });
});
