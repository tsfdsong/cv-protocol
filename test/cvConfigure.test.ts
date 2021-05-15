import { expect, use } from "chai";
import { MockProvider, solidity } from "ethereum-waffle";
import { Contract, ContractFactory } from "ethers";
import CVCfg = require("../build/waffle/CVCfg.json");

use(solidity);

describe("CVCfg", () => {
  const [owner, user1] = new MockProvider().getWallets();
  let cfg: Contract;

  beforeEach(async () => {
    const contractFactory = new ContractFactory(CVCfg.abi, CVCfg.bytecode, owner)
    cfg = await contractFactory.deploy();
    await cfg.setIndex(1, 1, 1);
    await cfg.setPieceCountAndCapicaty([1], [2], [10]);
  });

  it("has correct piece cap", async () => {
    expect(await cfg.getPieceCap(1)).eq(10);
  });

  it("has correct piece count", async () => {
    expect(await cfg.getPieceCount(1)).eq(2);
  });

  it("has correct common power", async () => {
    expect(await cfg.powerBy(0)).eq(100);
  });


  it("has correct common value", async () => {
    expect(await cfg.valueBy(0)).eq(10);
  });

  it("has correct get blind card", async () => {
    const [rolenum, level, piececount, piecenumber] = await cfg.getCards(12399, 1);
    console.log("getCards: %d %d %d %d", rolenum, level, piececount, piecenumber);
  });


  it("has correct blind price", async () => {
    const [price, isbusd] = await cfg.getPrice(1);
    expect(price).eq(50);
    expect(isbusd).eq(true);
  });
});
