const FakeMigrate= artifacts.require("./tokenV2/MigrateNFT");
const FakeCVMANAGER = artifacts.require("./tokenV2/CVNftManagerV2");

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
    oldnft = "0x4137Bd2dC8bCa33e2b7B203b6bddF0819BA7529D";
    newnft = "0xD6926D6E2e3D2aeAE4D30b715b68E07d1d3EA08c";
  }

  if (network == 'mainnet') {
    oldnft = "0x4137Bd2dC8bCa33e2b7B203b6bddF0819BA7529D";
    newnft = "0xD6926D6E2e3D2aeAE4D30b715b68E07d1d3EA08c";
  }

  mig.setOldNFTContract(oldnft,{ from: sender });
  mig.setNewNFTContract(newnft,{ from: sender });

  //nft
  let nftInstance = await FakeCVMANAGER.at(newnft);
  await nftInstance.setBlindOperator(mig.address, true, { from: sender });

  // await mig.updateBlindCount([sender],[10]);
};
