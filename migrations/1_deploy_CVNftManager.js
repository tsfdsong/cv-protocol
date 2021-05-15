const FakeBUSDT = artifacts.require("./token/BUSDToken");
const FakeCVD = artifacts.require("./token/CVDToken");
const FakeCONFIG = artifacts.require("./config/CVCfg");
const FakeCVMANAGER = artifacts.require("./token/CVNftManager");
const CVStaking = artifacts.require("./staking/CVStaking");
const MultiAcc = artifacts.require("./accounts/MultipleSignaturesAccount");

const HDWalletProvider = require('@truffle/hdwallet-provider');
const Web3 = require('web3');

module.exports = async (deployer, network) => {

  const accounts = await web3.eth.getAccounts();
  let sender = accounts[0];
  console.log('Attempting to deploy from account', sender);

  //1. deploy Token contract
  let cvd = await deployer.deploy(FakeCVD, "CVD TOKEN", "CVD", { from: sender });

  var busd;
  if (network == 'development') {
    busd = await deployer.deploy(FakeBUSDT, "BUSD TOKEN", "BUSD", { from: sender });
    busd = busd.address;
  }

  if (network == 'testnet') {
    busd = "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47";
  }

  if (network == 'mainnet') {
    busd = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  }

  //2. deploy config contract
  let cfg = await deployer.deploy(FakeCONFIG, { from: sender });

  //3. deploy multisig account contract
  let income = await deployer.deploy(MultiAcc, "Income Multisignature Contract", { from: sender });
  let platform = await deployer.deploy(MultiAcc, "Platform Multisignature Contract", { from: sender });

  //4. deploy nft manager contract
  let nft = await deployer.deploy(FakeCVMANAGER, busd, cvd.address, cfg.address, income.address, { from: sender });

  // console.log(nft.address, "CVNftManager.address");
  //5. deploy staking contract
  let cvStaking = await deployer.deploy(CVStaking, nft.address, { from: sender });

  //6. init config and parameters
  //cfg
  await cfg.setIndex(1, 1, 30, { from: sender });
  // await cfg.setPieceCountAndCapicaty([1], [2], [10], { from: sender });

  //staking
  await cvStaking.setBoxIncomePerBlock(1, { from: sender });
  await cvStaking.setCvcIncomePerBlock(0, { from: sender });
  await cvStaking.setBoxPrice(1, 500, { from: sender });
  await cvStaking.setBoxPrice(2, 500, { from: sender });
  await cvStaking.setBoxPrice(3, 500, { from: sender });
  // cvc
  await cvStaking.setCVCAddress(cvd.address, { from: sender });
  // platform
  await cvStaking.setPlatformAccountAddress(platform.address, { from: sender });
  // mint cvc
  const amount = "100000000000000000000000000";
  await cvd.mint(platform.address, amount, { from: sender });
  await platform.approve(cvd.address, cvStaking.address, amount, { from: sender });

  //nft
  await nft.setBlindOperator(cvStaking.address, true, { from: sender });
};
