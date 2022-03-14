

  // it('only owner can increase score', async function () {
  //   const signedScoresPool = await newPool(signedScoresPoolFactory, manager1);

  //   await signedScoresPool.connect(manager1).increaseBaseScore(1);
  //   await expect(signedScoresPool.connect(manager2).increaseBaseScore(2)).to.be.revertedWith(
  //     'Ownable: caller is not the owner'
  //   )
  // })

  describe('increase base score', function () {
    it('Group manager can increase base score immediately', async function () {
      const scoreBefore = await upala.connect(manager1).groupBaseScore(manager1Group)
      await upala.connect(manager1).increaseBaseScore(scoreBefore.add(scoreChange))
      const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
      expect(scoreAfter.sub(scoreBefore)).to.eq(scoreChange)
    })

    // only group manager todo
  })

  describe('decrease base score', function () {
    let newScore
    before('Commit hash', async () => {
      // scoreBefore =
      newScore = (await upala.connect(manager1).groupBaseScore(manager1Group)).sub(1)
      hash = utils.solidityKeccak256(['string', 'uint256', 'bytes32'], ['setBaseScore', newScore, secret])
      await upala.connect(manager1).commitHash(hash)
    })
  })
  
describe('SCORE BUNDLES MANAGEMENT', function () {
    let someRoot
    let delRootCommitHash
    before('Commit hash', async () => {
      someRoot = utils.formatBytes32String('Decentralize the IDs')
      delRootCommitHash = utils.solidityKeccak256(['string', 'uint256', 'bytes32'], ['deleteRoot', someRoot, secret])
    })
  
    it('group manager can publish new merkle root immediately', async function () {
      await upala.connect(manager1).publishRoot(someRoot)
      expect(await upala.roots(manager1Group, someRoot)).to.eq((await time.latest()).toString())
    })
  
    it('cannot publish commit before root', async function () {
      await upala.connect(manager1).commitHash(delRootCommitHash)
      await upala.connect(manager1).publishRoot(someRoot)
      await time.increase(attackWindow.toNumber())
      await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
        'Commit is submitted before root'
      )
    })
  
    it('cannot delete with wrong secret', async function () {
      await upala.connect(manager1).publishRoot(someRoot)
      await upala.connect(manager1).commitHash(delRootCommitHash)
      await time.increase(attackWindow.toNumber())
      await expect(upala.connect(manager1).deleteRoot(someRoot, wrongSecret)).to.be.revertedWith(
        'No such commitment hash'
      )
    })
  
    it('can delete after attack window and before execution window', async function () {
      await upala.connect(manager1).deleteRoot(someRoot, secret)
      expect(await upala.commitsTimestamps(manager1Group, delRootCommitHash)).to.eq(0)
      expect(await upala.roots(manager1Group, someRoot)).to.eq(0)
    })
  })