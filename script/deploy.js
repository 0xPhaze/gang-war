const { ethers } = require("hardhat");

async function main() {
  const owner = await ethers.getSigner();

  const MockERC721UDSLogic = await ethers.getContractFactory("MockERC721UDS");
  const mockERC721UDSLogic = await MockERC721UDSLogic.deploy();

  await mockERC721UDSLogic.deployed();

  const initData = MockERC721UDSLogic.interface.encodeFunctionData("init", ["TestERC721UDS", "TERC721"]);

  const Proxy = await ethers.getContractFactory("ERC1967Proxy");
  const proxy = await Proxy.deploy(mockERC721UDSLogic.address, initData);

  console.log(`proxy: "${proxy.address}",`);
  console.log(`mockERC721UDSLogic: "${mockERC721UDSLogic.address}",`);

  console.log(`npx hardhat verify ${proxy.address} ${mockERC721UDSLogic.address} ${initData} --network rinkeby`);
  console.log(`npx hardhat verify ${mockERC721UDSLogic.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
