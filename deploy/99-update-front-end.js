const { ethers, network } = require("hardhat");
const fs = require("fs");

// This might change
const frontEndContractsFile = "../nextjs-nft-marketplace/constants/networkMapping.json";
const frontEndAbiLocation = "../nextjs-nft-marketplace/constants/";
module.exports = async function () {
  if (process.env.UPDATE_FRONT_END === "true") {
    console.log("Updating front end...");
    await updateContractAddresses();
    await updateAbi();
  }
};

async function updateAbi() {
  const nftMarketplace = await ethers.getContract("NftMarketPlace");
  fs.writeFileSync(
    `${frontEndAbiLocation}NftMarketPlace.json`,
    nftMarketplace.interface.format(ethers.utils.FormatTypes.json)
  );

  const basicNft = await ethers.getContract("BasicNft");
  fs.writeFileSync(
    `${frontEndAbiLocation}BasicNft.json`,
    basicNft.interface.format(ethers.utils.FormatTypes.json)
  );
}

async function updateContractAddresses() {
  const nftMarketplace = await ethers.getContract("NftMarketPlace");
  const chainId = network.config.chainId.toString();
  const contractAddresses = JSON.parse(fs.readFileSync(frontEndContractsFile, "utf8"));
  if (chainId in contractAddresses) {
    if (!contractAddresses[chainId]["NftMarketPlace"].includes(nftMarketplace.address)) {
      contractAddresses[chainId]["NftMarketPlace"].push(nftMarketplace.address);
    } else {
      contractAddresses[chainId] = { NftMarketPlace: [nftMarketplace.address] };
    }
  }
  fs.writeFileSync(frontEndContractsFile, JSON.stringify(contractAddresses, null, 2));
}

module.exports.tags = ["all", "frontend"];
