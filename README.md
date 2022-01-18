[![hackmd-github-sync-badge](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA/badge)](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA)

# Upala digital identity

## Prerequisites

1. Install [hardhat](https://github.com/nomiclabs/buidler)
2. Install node modules - run 'yarn' or 'npm install'

## Run tests

1. Run hardhat local network - In project root open terminal window and run 'npx hardhat node'
2. In the same terminal where you deployed Upala run 'npx hardhat test /test/upala.js'

## Deploy Upala to local network:

1. Run hardhat local network - In project root open terminal window and run 'npx hardhat node'
2. Deploy Upala - In project root open another terminal window and run 'npx hardhat run scripts/upala-admin.js'

## Deploy Upala to a live network (testnets or main) - draft:

1. In upala project root. Copy-paste secrets-template.js to secrets.js (don't need any data there until you deploy to a live network).
2. To deploy to a network run 'npx hardhat run scripts/upala-admin.js --network test-net-name' where test-net-name = main | rinkeby | goerli | mumbai...

## Links

- [Front-end repo](https://github.com/porobov/upala-front)
- [Pale blue paper](https://upala-docs.readthedocs.io/en/latest/)
- [Medium blog](https://medium.com/six-degrees-of-separation/)
