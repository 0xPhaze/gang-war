const { ethers } = require("hardhat");

async function main() {
  const owner = await ethers.getSigner();

  const Logic = await ethers.getContractFactory("MockERC721UDS");
  const logic = await Logic.deploy();

  await logic.deployed();

  const data = Logic.interface.encodeFunctionData("init", ["TestERC721UDS", "TERC721"]);

  const Proxy = await ethers.getContractFactory("ERC1967Proxy");
  const proxy = await Proxy.deploy(logic.address, data);

  console.log(`proxy: "${proxy.address}",`);
  console.log(`logic: "${logic.address}",`);

  console.log(`npx hardhat verify ${proxy.address} ${logic.address} ${data} --network rinkeby`);
  console.log(`npx hardhat verify ${logic.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
