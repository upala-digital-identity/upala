import chai, { expect } from 'chai'
import { ethers } from 'hardhat'
import { time } from '@openzeppelin/test-helpers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { Contract, BigNumber, constants } from 'ethers'
import BalanceTree from '../src/balance-tree'

import Distributor from '../artifacts/contracts/protocol/MerkleDistributor.sol/MerkleDistributor.json'
import TestERC20 from '../artifacts/contracts/mockups/TestERC20.sol/TestERC20.json'
import Upala from '../artifacts/contracts/protocol/upala.sol/Upala.json'
import FakeDai from '../artifacts/contracts/mockups/fake-dai-mock.sol/FakeDai.json'
// import MerklePoolFactory from '../artifacts/contracts/pools/basic-pool.sol/MerklePoolFactory.json'
import { parseBalanceMap } from '../src/parse-balance-map'
import { Address } from 'cluster'

const { upgrades, artifacts } = require('hardhat')
const MerklePool = artifacts.require('MerklePool')
const MerklePoolFactory = artifacts.require('MerklePoolFactory')

chai.use(solidity)

const overrides = {
  gasLimit: 9999999,
}

const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000'

async function setupProtocol(admin, groupOwner) {
  const fakeDai: Contract = await deployContract(admin, FakeDai)
  const upala: Contract = await deployContract(admin, Upala)
  await upala.deployed()
  const merklePoolFactory = await deployContract(admin, MerklePoolFactory, [upala.address, fakeDai.address])
  await upala.approvePoolFactory(merklePoolFactory.address, 'true').then((tx) => tx.wait());

  // spawn a new pool by the factory
  const tx = await merklePoolFactory.connect(groupOwner).createPool();
  const receipt = await tx.wait(1);
  const newPoolEvent = receipt.events.filter((x) => {return x.event == "NewPool"});
  const newPoolAddress = newPoolEvent[0].args.newPoolAddress;
  const PoolContract = await ethers.getContractFactory("MerklePool");
  const merklePool: Contract = PoolContract.attach(newPoolAddress);

  return [fakeDai, upala, merklePool]
}

describe('MerkleDistributor', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999,
    },
  })

  const wallets = provider.getWallets()
  const [upalaAdmin, groupOwner0, wallet1, user0, user1, user2, manager1] = wallets

  // describe('#token', () => {
  //   it('returns the token address', async () => {
  //     const distributor = await deployContract(groupOwner0, Distributor, [], overrides)
  //     await distributor.publishScoreBundle(ZERO_BYTES32)
  //     expect(await distributor.token()).to.eq(token.address)
  //   })
  // })

  describe('#merkleRoot', () => {
    it('stores and returns the zero merkle root', async () => {
      const [fakeDai, upala, merklePool] = await setupProtocol(upalaAdmin, groupOwner0)

      const tx = await merklePool.connect(groupOwner0).publishScoreBundle(ZERO_BYTES32)
      const block = await provider.getBlock((await tx.wait(1)).blockNumber)
      const now = (await block).timestamp

      const timestamp = await merklePool.connect(groupOwner0).roots(ZERO_BYTES32);

      expect(timestamp - now).to.eq(0)
    })
  })  

  describe('#claim', () => {
    it('fails for empty proof', async () => {
      const [fakeDai, upala, merklePool] = await setupProtocol(upalaAdmin, groupOwner0)
      const tx = await merklePool.connect(groupOwner0).publishScoreBundle(ZERO_BYTES32)
      await upala.connect(user0).newIdentity(user0.address)

      const user0id = await upala.connect(user0).myId()
      const index = 0; 
      const score = 0; 
      const proof = [];

      await expect(merklePool.connect(user0).attack(user0id, index, score, proof)).to.be.revertedWith(
        'MerkleDistributor: Invalid proof.'
      )
    })
  })

    //todo: was wrong in Uniswap merkle distibutor, do it right!
    // it('fails for invalid index', async () => {
    //   const distributor = await deployContract(groupOwner0, Distributor, [], overrides)
    //   await distributor.publishScoreBundle(ZERO_BYTES32)
    //   await expect(distributor.claim(0, groupOwner0.address, 10, [])).to.be.revertedWith(
    //     'MerkleDistributor: Invalid proof.'
    //   )
    // })

    describe('two account tree', () => {
      let merklePool: Contract
      let fakeDai: Contract
      let upala: Contract
      let tree: BalanceTree
      let user0id: string
      let user1id: string
      let baseScore: BigNumber
      beforeEach('deploy', async () => {
        [fakeDai, upala, merklePool] = await setupProtocol(upalaAdmin, groupOwner0)
        await upala.connect(user0).newIdentity(user0.address)
        await upala.connect(user1).newIdentity(user1.address)
        user0id = await upala.connect(user0).myId()
        user1id = await upala.connect(user1).myId()
        tree = new BalanceTree([
          { account: user0id, amount: BigNumber.from(100) },
          { account: user1id, amount: BigNumber.from(101) },
        ])
        const root = tree.getHexRoot()
        await merklePool.connect(groupOwner0).publishScoreBundle(root).then((tx) => tx.wait())
        // await token.setBalance(merklePool.address, 201)
      })

      it('successful verification', async () => {
        const root = tree.getHexRoot()
        const proof0 = tree.getProof(0, user0id, BigNumber.from(100))

        // const proof1 = tree.getProof(1, user1id, BigNumber.from(101))
        // console.log("proof0", proof0)
        // console.log("proof1", proof1)
        console.log("TS Leaf", (BalanceTree.toNode(0, user0id, BigNumber.from(100))).toString('hex'))
        console.log("Contract leaf", await merklePool.connect(user0).hack_leaf(0, user0id, 100, proof0, overrides))
        
        console.log("root", root)
        console.log("hack_computeRoot", await merklePool.connect(user0).hack_computeRoot(0, user0id, 100, proof0, overrides))
        
        const proof0buff = proof0.map((el) => Buffer.from(el.slice(2), 'hex'))
        const rootBuff = Buffer.from(root.slice(2), 'hex')
        console.log(BalanceTree.verifyProof(0, user0id, BigNumber.from(100), proof0buff, rootBuff))
        // todo const totalScore1
        expect(await merklePool.connect(user0).myScore(0, user0id, 100, proof0, overrides)).to.be.eq(100)
        
        // const proof1 = tree.getProof(1, user1id, BigNumber.from(101))
        // expect(await merklePool.connect(user1).myScore(1, user1id, 101, proof1, overrides)).to.be.eq(101)
      })

      // it('successful attack', async () => {
      //   const proof0 = tree.getProof(0, user0id, BigNumber.from(100))
      //   await expect(merklePool.myScore(0, user0id, 100, proof0, overrides))
      //     .to.emit(merklePool, 'myScoreed')
      //     .withArgs(0, user0id, 100)
      //   const proof1 = tree.getProof(1, user1id, BigNumber.from(101))
      //   await expect(merklePool.myScore(1, user1id, 101, proof1, overrides))
      //     .to.emit(merklePool, 'myScoreed')
      //     .withArgs(1, user1id, 101)
      // })
    })
  /*
      it('cannot claim for address other than proof', async () => {
        const proof0 = tree.getProof(0, wallet0.address, BigNumber.from(100))
        await expect(distributor.claim(1, wallet1.address, 101, proof0, overrides)).to.be.revertedWith(
          'MerkleDistributor: Invalid proof.'
        )
      })

      it('cannot claim more than proof', async () => {
        const proof0 = tree.getProof(0, wallet0.address, BigNumber.from(100))
        await expect(distributor.claim(0, wallet0.address, 101, proof0, overrides)).to.be.revertedWith(
          'MerkleDistributor: Invalid proof.'
        )
      })

      // it('gas', async () => {
      //   const proof = tree.getProof(0, wallet0.address, BigNumber.from(100))
      //   const tx = await distributor.claim(0, wallet0.address, 100, proof, overrides)
      //   const receipt = await tx.wait()
      //   expect(receipt.gasUsed).to.eq(78466)
      // })
    })
    
    describe('larger tree', () => {
      let distributor: Contract
      let tree: BalanceTree
      beforeEach('deploy', async () => {
        tree = new BalanceTree(
          wallets.map((wallet, ix) => {
            return { account: wallet.address, amount: BigNumber.from(ix + 1) }
          })
        )
        distributor = await deployContract(wallet0, Distributor, [], overrides)
        await distributor.publishScoreBundle(tree.getHexRoot())
        await token.setBalance(distributor.address, 201)
      })

      it('claim index 4', async () => {
        const proof = tree.getProof(4, wallets[4].address, BigNumber.from(5))
        await expect(distributor.claim(4, wallets[4].address, 5, proof, overrides))
          .to.emit(distributor, 'Claimed')
          .withArgs(4, wallets[4].address, 5)
      })

      it('claim index 9', async () => {
        const proof = tree.getProof(9, wallets[9].address, BigNumber.from(10))
        await expect(distributor.claim(9, wallets[9].address, 10, proof, overrides))
          .to.emit(distributor, 'Claimed')
          .withArgs(9, wallets[9].address, 10)
      })

      // it('gas', async () => {
      //   const proof = tree.getProof(9, wallets[9].address, BigNumber.from(10))
      //   const tx = await distributor.claim(9, wallets[9].address, 10, proof, overrides)
      //   const receipt = await tx.wait()
      //   expect(receipt.gasUsed).to.eq(80960)
      // })

      // it('gas second down about 15k', async () => {
      //   await distributor.claim(
      //     0,
      //     wallets[0].address,
      //     1,
      //     tree.getProof(0, wallets[0].address, BigNumber.from(1)),
      //     overrides
      //   )
      //   const tx = await distributor.claim(
      //     1,
      //     wallets[1].address,
      //     2,
      //     tree.getProof(1, wallets[1].address, BigNumber.from(2)),
      //     overrides
      //   )
      //   const receipt = await tx.wait()
      //   expect(receipt.gasUsed).to.eq(65940)
      // })
    })

    describe('realistic size tree', () => {
      let distributor: Contract
      let tree: BalanceTree
      const NUM_LEAVES = 100_000
      const NUM_SAMPLES = 25
      const elements: { account: string; amount: BigNumber }[] = []
      for (let i = 0; i < NUM_LEAVES; i++) {
        const node = { account: wallet0.address, amount: BigNumber.from(100) }
        elements.push(node)
      }
      tree = new BalanceTree(elements)

      it('proof verification works', () => {
        const root = Buffer.from(tree.getHexRoot().slice(2), 'hex')
        for (let i = 0; i < NUM_LEAVES; i += NUM_LEAVES / NUM_SAMPLES) {
          const proof = tree
            .getProof(i, wallet0.address, BigNumber.from(100))
            .map((el) => Buffer.from(el.slice(2), 'hex'))
          const validProof = BalanceTree.verifyProof(i, wallet0.address, BigNumber.from(100), proof, root)
          expect(validProof).to.be.true
        }
      })

      beforeEach('deploy', async () => {
        distributor = await deployContract(wallet0, Distributor, [], overrides)
        await distributor.publishScoreBundle(tree.getHexRoot())
        await token.setBalance(distributor.address, constants.MaxUint256)
      })
      /*
      it('gas', async () => {
        const proof = tree.getProof(50000, wallet0.address, BigNumber.from(100))
        const tx = await distributor.claim(50000, wallet0.address, 100, proof, overrides)
        const receipt = await tx.wait()
        expect(receipt.gasUsed).to.eq(91650)
      })
      it('gas deeper node', async () => {
        const proof = tree.getProof(90000, wallet0.address, BigNumber.from(100))
        const tx = await distributor.claim(90000, wallet0.address, 100, proof, overrides)
        const receipt = await tx.wait()
        expect(receipt.gasUsed).to.eq(91586)
      })
      it('gas average random distribution', async () => {
        let total: BigNumber = BigNumber.from(0)
        let count: number = 0
        for (let i = 0; i < NUM_LEAVES; i += NUM_LEAVES / NUM_SAMPLES) {
          const proof = tree.getProof(i, wallet0.address, BigNumber.from(100))
          const tx = await distributor.claim(i, wallet0.address, 100, proof, overrides)
          const receipt = await tx.wait()
          total = total.add(receipt.gasUsed)
          count++
        }
        const average = total.div(count)
        expect(average).to.eq(77075)
      })
      // this is what we gas golfed by packing the bitmap
      it('gas average first 25', async () => {
        let total: BigNumber = BigNumber.from(0)
        let count: number = 0
        for (let i = 0; i < 25; i++) {
          const proof = tree.getProof(i, wallet0.address, BigNumber.from(100))
          const tx = await distributor.claim(i, wallet0.address, 100, proof, overrides)
          const receipt = await tx.wait()
          total = total.add(receipt.gasUsed)
          count++
        }
        const average = total.div(count)
        expect(average).to.eq(62824)
      })
      
    
  })

  describe('parseBalanceMap', () => {
    let distributor: Contract
    let claims: {
      [account: string]: {
        index: number
        amount: string
        proof: string[]
      }
    }
    beforeEach('deploy', async () => {
      const {
        claims: innerClaims,
        merkleRoot,
        tokenTotal,
      } = parseBalanceMap({
        [wallet0.address]: 200,
        [wallet1.address]: 300,
        [wallets[2].address]: 250,
      })
      expect(tokenTotal).to.eq('0x02ee') // 750
      claims = innerClaims
      distributor = await deployContract(wallet0, Distributor, [], overrides)
      await distributor.publishScoreBundle(merkleRoot)
      await token.setBalance(distributor.address, tokenTotal)
    })

    it('check the proofs is as expected', () => {
      expect(claims).to.deep.eq({
        [wallet0.address]: {
          index: 0,
          amount: '0xc8',
          proof: ['0x2a411ed78501edb696adca9e41e78d8256b61cfac45612fa0434d7cf87d916c6'],
        },
        [wallet1.address]: {
          index: 1,
          amount: '0x012c',
          proof: [
            '0xbfeb956a3b705056020a3b64c540bff700c0f6c96c55c0a5fcab57124cb36f7b',
            '0xd31de46890d4a77baeebddbd77bf73b5c626397b73ee8c69b51efe4c9a5a72fa',
          ],
        },
        [wallets[2].address]: {
          index: 2,
          amount: '0xfa',
          proof: [
            '0xceaacce7533111e902cc548e961d77b23a4d8cd073c6b68ccf55c62bd47fc36b',
            '0xd31de46890d4a77baeebddbd77bf73b5c626397b73ee8c69b51efe4c9a5a72fa',
          ],
        },
      })
    })
    
  })
  })*/
})
