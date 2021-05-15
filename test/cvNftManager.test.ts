import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { Contract } from "ethers";
import ICVCfg = require("../build/waffle/CVCfg.json");
import CVNftManager = require("../build/waffle/CVNftManager.json");

import FakeBUSDT = require("../build/waffle/BUSDToken.json");
import FakeCVC = require("../build/waffle/CVCToken.json");

use(solidity);

describe("CVNftManager", () => {
  const [owner, user1] = new MockProvider().getWallets();
  let busd: Contract;
  let cvc: Contract;
  let cfg: Contract;
  let nftManager: Contract;

  beforeEach(async () => {
    busd = await deployContract(owner, FakeBUSDT, ["BUSD TOKEN", "BUSD"]);
    cvc = await deployContract(owner, FakeCVC, ["CVC TOKEN", "CVC"]);

    cfg = await deployContract(owner, ICVCfg);
    await cfg.setIndex(1, 1, 1);
    await cfg.setPieceCountAndCapicaty([1], [2], [10]);

    nftManager = await deployContract(owner, CVNftManager, [busd.address, cvc.address, cfg.address, owner.address]);
  });

  it("has correct get blind card", async () => {
    const [rolenum, level, piececount, piecenumber] = await cfg.getCards(12399, 1);
    console.log("getCards: %d %d %d %d", rolenum, level, piececount, piecenumber);
  });


  it("has correct lotteryed", async () => {
    expect(nftManager.lottery(1, 12399)).to.emit(nftManager, "EventLottery").withArgs(1, 2);
  });
});
