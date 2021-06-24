const FakeMigrate= artifacts.require("./tokenV2/MigrateNFT");
const FakeCVMANAGER = artifacts.require("./tokenV2/CVNftManagerV2");
const CVMANAGER = artifacts.require("./token/CVNftManager");

const HDWalletProvider = require('@truffle/hdwallet-provider');
const Web3 = require('web3');

module.exports = async (deployer, network) => {

  const accounts = await web3.eth.getAccounts();
  let sender = accounts[0];
  console.log('Attempting to deploy from account', sender);

  var mig;

  var oldnft;
  var newnft;

  if (network == 'testnet') {
    oldnft = "0x4137Bd2dC8bCa33e2b7B203b6bddF0819BA7529D";
    newnft = "0xeb6F20757C511e47ab5108a82d3C98f4BA30610C";
    mig = "0x23b25C364c6F5b4b54f28F22e50aD1eF7a22bEC0";
  }

  if (network == 'mainnet') {
    oldnft = "0x4137Bd2dC8bCa33e2b7B203b6bddF0819BA7529D";
    newnft = "0xeb6F20757C511e47ab5108a82d3C98f4BA30610C";
    mig = "0x23b25C364c6F5b4b54f28F22e50aD1eF7a22bEC0";
  }

  //nft
  // let oldNFT = await CVMANAGER.at(oldnft);
  // console.log('old nft info: ', oldNFT.getCard(0));


  let migInstance = await FakeMigrate.at(mig);
  await migInstance.updateBatchPuzzle("0x076F83C7D56CD6174f5a1d10283B2DC9558E1924", [0], { from: sender });
};
