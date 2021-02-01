[![hackmd-github-sync-badge](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA/badge)](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA)
## Upala digital identity


## Links 
- [Front-end repo](https://github.com/porobov/upala-front)
- [Pale blue paper](https://upala-docs.readthedocs.io/en/latest/)
- [Medium blog](https://medium.com/six-degrees-of-separation/)

## Deploy and publish artifacts to upala front-end:
1. Install [hardhat](https://github.com/nomiclabs/buidler)
2. In upala project root. Copy-paste secrets-template.js to secrets.js (don't need any data there until you deploy to a live network).
3. In ./scripts/deploy-and-publish.js find this line
const newPublishDir = "../scaffold-eth/rad-new-dapp/packages/contracts/";
Replace it with the path to the upala front-end contracts folder (smth. like your-projects-dir/upala-front/packages/react-app/src/contracts/)
5. run buidler local network at 8545
6. In upala project root. Run 'npx buidler run scripts/deploy-and-publish.js'
7. To deploy to a network run 'npx buidler run scripts/deploy-and-publish.js --network test-net-name' where test-net-name = main | rinkeby | goerli | mumbai...

