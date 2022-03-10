////

//// WARNING!!! This whole script is under deprication!

////
const bre = require('hardhat')
const { ethers, upgrades } = require('hardhat')
const fs = require('fs')
const chalk = require('chalk')
const exampleDappDir = '../example-app/packages/contracts/'
const newPublishDir = '../scaffold-eth/rad-new-dapp/packages/contracts/'

async function main() {
  const networkName = bre.network.name

  var finalContracts = {}
  var finalGroups = {}

  console.log(chalk.green('\n👤 USERS\n'))
  /////////////////////////////////////////////////

  const [owner, m1, m2, m3, u1, u2, u3] = await ethers.getSigners()
  console.log(
    'owner',
    chalk.blue(await owner.getAddress()),
    ethers.utils.formatEther(await owner.getBalance()),
    '\nm1',
    chalk.blue(await m1.getAddress()),
    ethers.utils.formatEther(await m1.getBalance()),
    '\nm2',
    chalk.blue(await m2.getAddress()),
    ethers.utils.formatEther(await m2.getBalance()),
    '\nm3',
    chalk.blue(await m3.getAddress()),
    ethers.utils.formatEther(await m3.getBalance()),
    '\nu1',
    chalk.blue(await u1.getAddress()),
    ethers.utils.formatEther(await u1.getBalance()),
    '\nu2',
    chalk.blue(await u2.getAddress()),
    ethers.utils.formatEther(await u2.getBalance()),
    '\nu3',
    chalk.blue(await u3.getAddress()),
    ethers.utils.formatEther(await u3.getBalance())
  )

  if (networkName == 'localhost') {
    owner.sendTransaction({
      to: '0xb4124cEB3451635DAcedd11767f004d8a28c6eE7',
      value: ethers.utils.parseEther('1.0'),
    })
  }
  console.log(chalk.green('\n📡 DEPLOYING (', networkName, ')\n'))
  /////////////////////////////////////////////////

  async function deployContract(contractName, ...args) {
    const contractFactory = await ethers.getContractFactory(contractName)
    const contractInstance = await contractFactory.deploy(...args)
    await contractInstance.deployed()

    console.log(chalk.cyan(contractName), 'deployed to:', chalk.magenta(contractInstance.address))
    finalContracts[contractName] = {
      address: contractInstance.address,
      abi: contractInstance.interface.format('json'), // TODO will it work as ABI in Front-end
    }

    return contractInstance
  }

  // await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  // upala = await deployContract("Upala")

  // deploy upgradable Upala
  const Upala = await ethers.getContractFactory('Upala')
  const upala = await upgrades.deployProxy(Upala)
  await upala.deployed()
  finalContracts['Upala'] = {
    address: upala.address,
    abi: upala.interface.format('json'), // TODO will it work as ABI in Front-end
  }
  console.log(chalk.cyan('Upala'), 'deployed to:', chalk.magenta(upala.address))

  // Testing environment
  fakeDai = await deployContract('FakeDai')
  merklePoolFactory = await deployContract('MerklePoolFactory', fakeDai.address)
  await upala.setapprovedPoolFactory(merklePoolFactory.address, 'true').then((tx) => tx.wait())
  console.log('approvedPoolFactory')

  console.log(chalk.green('\nDEPLOYING GROUPS \n'))
  /////////////////////////////////////////////////

  const defaultBotReward = ethers.utils.parseEther('3')
  const poolDonation = ethers.utils.parseEther('1000')

  async function deployGroup(groupName, manager, multiplier) {
    await upala.newGroup(manager.getAddress(), merklePoolFactory.address)
    groupID = await upala.getGroupID(manager.getAddress())
    groupPool = await upala.getGroupPool(groupID)

    finalGroups[groupName] = {
      address: groupID,
      pool: groupPool,
    }

    await fakeDai.freeDaiToTheWorld(groupPool, poolDonation.mul(multiplier))

    console.log(
      chalk.blue('Upala ID:'),
      groupID.toNumber(),
      chalk.blue('Pool:'),
      groupPool,
      chalk.blue('Bal:'),
      ethers.utils.formatEther(await fakeDai.balanceOf(groupPool))
    )

    return [groupID, groupID]
  }

  const [group1, group1ID] = await deployGroup('DemocracyEarth', m1, 1)
  const [group2, group2ID] = await deployGroup('BrightID', m2, 2)
  const [bladerunner, bladerunnerID] = await deployGroup('BladerunnerDAO', m3, 5)

  console.log(chalk.green('\nTESTING GROUPS\n'))
  ///////////////////////////////////////////////

  // Upala prototype UX
  await upala
    .connect(u1)
    .newIdentity(u1.getAddress())
    .then((tx) => tx.wait())
  await upala
    .connect(u2)
    .newIdentity(u2.getAddress())
    .then((tx) => tx.wait())

  // ID details
  const user1ID = await upala.connect(u1).myId()
  const user2ID = await upala.connect(u2).myId()

  console.log(chalk.blue('User1 Address: '), await u1.getAddress())
  console.log(chalk.blue('User2 Address: '), await u2.getAddress())

  console.log(chalk.blue('User1 ID: '), user1ID.toNumber())
  console.log(chalk.blue('User2 ID: '), user2ID.toNumber())

  /*
  console.log(chalk.green("\nTESTING DAPP\n"));
  ///////////////////////////////////////////////

  // deploy DApp
  // setUpala
  // approve score provider by id
  // constructor (address upalaAddress, address trustedProviderUpalaID) 
  sampleDapp = await deployContract("UBIExampleDApp", upala.address, bladerunnerID);
  
  // await bladerunner.connect(u1).freeAppCredit(sampleDapp.address).then((tx) => tx.wait());
  const path = [user1ID, group1ID, bladerunnerID];
  await sampleDapp.connect(u1).claimUBI(path).then((tx) => tx.wait());
  // console.log("App credit: ", ethers.utils.formatEther(await upala.connect(u1).appBalance(bladerunnerID, sampleDapp.address)));

  console.log("UBIExampleDApp address: ", sampleDapp.address);
  // console.log("User 1 UBI balance: ", await sampleDapp.connect(u1).myUBIBalance());
  console.log("User 1 UBI balance: ", ethers.utils.formatEther(await sampleDapp.connect(u1).myUBIBalance()));

*/

  // console.log(finalContracts);
  //   deployer.deploy(MerklePoolFactory, FakeDai.address).then(() => {
  //     Upala.deployed().then(upala => {
  //         return upala.setapprovedPoolFactory(MerklePoolFactory.address, "true");
  //     });
  // });

  console.log(chalk.green('\n📡 PUBLISHING\n'))

  function exportContracts(contracts, groups, pubDir, network) {
    function exportAddresses(contracts) {
      fileContents = 'const addresses = {'
      if (contracts) {
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += '\n  ' + contract + ': "' + params.address + '",'
        }
      }
      fileContents += '\n};\nexport default addresses;'
      return fileContents
    }

    function exportAbis(contracts) {
      function abiImports(contracts) {
        fileContents = ''
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += 'import ' + contract + ' from "./abis/' + contract + '.json";\n'
        }
        return fileContents
      }

      function abisObject(contracts) {
        fileContents = '\nconst abis = {'
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += '\n  ' + contract + ': ' + contract + ','
        }
        fileContents += '\n}; \n\nexport default abis;'
        return fileContents
      }
      return abiImports(contracts) + abisObject(contracts)
    }

    const srcDir = pubDir + 'src/'
    const abisDir = pubDir + 'src/abis/'
    const addressesDir = pubDir + 'src/addresses/'
    const groupsDir = pubDir + 'src/groups/'

    // create dirs
    const dirs = [pubDir, srcDir, abisDir, addressesDir, groupsDir]
    dirs.forEach((entry) => {
      if (!fs.existsSync(entry)) {
        fs.mkdirSync(entry)
      }
    })

    // create empty addresses files if files don't exist
    const addressesFiles = [
      addressesDir + 'main.js',
      addressesDir + 'rinkeby.js',
      addressesDir + 'localhost.js',
      addressesDir + 'goerli.js',
      addressesDir + 'mumbai.js',
      addressesDir + 'bnbtest.js',

      groupsDir + 'main.js',
      groupsDir + 'rinkeby.js',
      groupsDir + 'localhost.js',
      groupsDir + 'goerli.js',
      groupsDir + 'mumbai.js',
      groupsDir + 'bnbtest.js',
    ]
    addressesFiles.forEach((path) => {
      if (!fs.existsSync(path)) {
        fs.writeFileSync(path, exportAddresses())
      }
    })

    // genrate addresses and abis files
    fs.writeFileSync(addressesDir + '/' + network + '.js', exportAddresses(contracts))
    fs.writeFileSync(groupsDir + '/' + network + '.js', exportAddresses(groups))
    for (const [contract, params] of Object.entries(contracts)) {
      fs.writeFileSync(abisDir + '/' + contract + '.json', JSON.stringify(params.abi))
    }
    fs.writeFileSync(srcDir + '/abis.js', exportAbis(contracts))

    // copy template files
    fs.copyFile('./scripts/exporter/index.js.template', srcDir + 'index.js', (err) => {
      if (err) throw err
    })
    fs.copyFile('./scripts/exporter/package.json.template', pubDir + '/package.json', (err) => {
      if (err) throw err
    })
  }

  exportContracts(finalContracts, finalGroups, newPublishDir, networkName)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
