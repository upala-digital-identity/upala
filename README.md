[![hackmd-github-sync-badge](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA/badge)](https://hackmd.io/tHhYT-4QRy-syvNkoBa_ZA)
## Upala digital identity


## Links 
- [Front-end repo](https://github.com/porobov/upala-front)
- [Pale blue paper](https://upala-docs.readthedocs.io/en/latest/)
- [Medium blog](https://medium.com/six-degrees-of-separation/)

## Deploy and publish artifacts to upala front-end:
1. Install [buidler](https://github.com/nomiclabs/buidler)
2. In upala project root. Copy-paste secrets-template.js to secrets.js (don't need any data there until you deploy to Kovan).
3. In ./scripts/sample-script.js find this line
const publishDir =  "../scaffold-eth/rad-new-dapp/packages/react-app/src/contracts/" + networkName;
Replace it with the path to the upala front-end contracts folder (smth. like your-projects-dir/upala-front/packages/react-app/src/contracts/)
4. Create "localhost" folder in your-projects-dir/upala-front/packages/react-app/src/contracts/
5. run buidler local network at 8545
6. In upala project root. Run 'npx buidler run scripts/sample-script.js'
7. To deploy to a testnet run 'npx buidler run scripts/sample-script.js --network test-net-name' where test-net-name = kovan | ropsten | rinkeby ...