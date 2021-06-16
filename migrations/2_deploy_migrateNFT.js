const FakeMigrate= artifacts.require("./token/MigrateNFT");

const HDWalletProvider = require('@truffle/hdwallet-provider');
const Web3 = require('web3');

module.exports = async (deployer, network) => {

  const accounts = await web3.eth.getAccounts();
  let sender = accounts[0];
  console.log('Attempting to deploy from account', sender);

  let mig = await deployer.deploy(FakeMigrate, { from: sender });

  var oldnft;
  var newnft;

  if (network == 'testnet') {
    oldnft = "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47";
    newnft = "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47";
  }

  if (network == 'mainnet') {
    oldnft = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
    newnft = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  }

  mig.setOldNFTContract(oldnft.address,{ from: sender });
  mig.setNewNFTContract(newnft.address,{ from: sender });

  //nft
  await newnft.setBlindOperator(mig.address, true, { from: sender });
};
