require("dotenv").config();

const fs = require("fs");
const { ethers } = require("ethers");

const dataBarons = require("./dataBarons.json");
const dataGangsters = require("./dataGangsters.json");
const deployments = require("../deployments/80001/deploy-latest.json");

let wallet = new ethers.Wallet(process.env.PRIVATE_KEY);

const signatures = {
  barons: {},
  gangsters: {},
};

console.log("Signer:", wallet.address);
console.log("GMCChild:", deployments.GMCChild);

const main = async () => {
  for (let i = 0; i < dataBarons.players.length; i++) {
    const player = ethers.utils.getAddress(dataBarons.players[i]);
    // const gang = dataBarons.gangs[i];

    const message = ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "bool"],
      [deployments.GMCChild, player, true]
      // ["address"],
      // [player]
    );

    const messageHash = ethers.utils.keccak256(message);

    signatures.barons[player.toLowerCase()] = await wallet.signMessage(ethers.utils.arrayify(messageHash));
  }

  for (let i = 0; i < dataGangsters.players.length; i++) {
    const player = ethers.utils.getAddress(dataGangsters.players[i]);
    // const gang = dataGangsters.gangs[i];

    if (player.toLowerCase() in signatures.barons) continue;

    const message = ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "bool"],
      [deployments.GMCChild, player, false]
      // ["address"],
      // [player]
    );

    const messageHash = ethers.utils.keccak256(message);

    signatures.gangsters[player.toLowerCase()] = await wallet.signMessage(ethers.utils.arrayify(messageHash));
  }

  fs.writeFile("signaturesDemo.json", JSON.stringify(signatures, null, 2), console.error);
};

main();
