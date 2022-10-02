require("dotenv").config();

const fs = require("fs");
const { ethers } = require("ethers");

const dataGangsters = require("./data/demoPlayers.json");
const deployments = require("../deployments/80001/deploy-latest.json");

// deployments.GMCChild = "0xA6eEC0D4dACF63697f669f21ee58A49cB13EaB77";

let wallet = new ethers.Wallet(process.env.PRIVATE_KEY);

const signatures = {
  gangsters: {},
};

console.log("Signer:", wallet.address);
console.log("GMCChild:", deployments.GMCChild);

const main = async () => {
  // gangsters
  for (let i = 0; i < dataGangsters.players.length; i++) {
    const player = ethers.utils.getAddress(dataGangsters.players[i]);
    // const gang = dataGangsters.gangs[i];

    // if (player.toLowerCase() in signatures.barons) continue;

    const message = ethers.utils.defaultAbiCoder.encode(
      ["address", "address"],
      [deployments.GMCChild, player]
    ); // prettier-ignore

    const messageHash = ethers.utils.keccak256(message);

    signatures.gangsters[player.toLowerCase()] = await wallet.signMessage(ethers.utils.arrayify(messageHash));
  }

  signatures.signer = wallet.address;
  signatures.GMCChild = deployments.GMCChild;

  fs.writeFile("signaturesDemo.json", JSON.stringify(signatures, null, 2), console.error);
};

main();
