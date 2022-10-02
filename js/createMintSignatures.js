require("dotenv").config();

const fs = require("fs");
const { ethers } = require("ethers");

const dataWhitelist = require("./data/whitelist.json");
const deployments = require("../deployments/80001/deploy-latest.json");

let wallet = new ethers.Wallet(process.env.PRIVATE_KEY);

const signatures = {};

console.log("Signer:", wallet.address);
console.log("GMCRoot:", deployments.GMCRoot);

const main = async () => {
  for (let limit in dataWhitelist) {
    for (let i = 0; i < dataWhitelist[limit].length; i++) {
      const player = ethers.utils.getAddress(dataWhitelist[limit][i]);

      const message = ethers.utils.defaultAbiCoder.encode(
        ["address", "address", "uint256"],
        [deployments.GMCRoot, player, limit]
      );

      const messageHash = ethers.utils.keccak256(message);

      signatures[player.toLowerCase()] = [limit, await wallet.signMessage(ethers.utils.arrayify(messageHash))];
    }
  }

  signatures.Signer = wallet.address;
  signatures.GMCRoot = deployments.GMCRoot;

  fs.writeFile("signaturesGMCMint.json", JSON.stringify(signatures, null, 2), console.error);
};

main();
