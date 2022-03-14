// README
// This is future work - for Merkle pools
// Signed score pools don't need that

describe('COMMITMENTS', function () {
  it('a group can issue a commitment', async function () {
    const someHash = utils.formatBytes32String('First commitment!')
    await upala.connect(manager1).commitHash(someHash)
    const now = await time.latest()
    expect(await upala.commitsTimestamps(manager1Group, someHash)).to.eq(now.toString())
    // fast-forward
    await time.increase(1000)
    const otherHash = utils.formatBytes32String('Second commitment!')
    await upala.connect(manager1).commitHash(otherHash)
    const then = await time.latest()
    expect(await upala.commitsTimestamps(manager1Group, otherHash)).to.eq(then.toString())
  })

  it('cannot decrease base score immediately', async function () {
    await expect(upala.connect(manager1).increaseBaseScore(scoreChange)).to.be.revertedWith(
      'To decrease score, make a commitment first'
    )
  })

  it('cannot decrease score immediately after commitment', async function () {
    await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
      'Attack window is not closed yet'
    )
  })

  it('cannot decrease score after execution window', async function () {
    await time.increase(executionWindow.add(attackWindow).toNumber())
    await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
      'Execution window is already closed'
    )
  })

  it('cannot decrease score with wrong secret', async function () {
    await upala.connect(manager1).commitHash(hash)
    await time.increase(attackWindow.toNumber())
    await expect(upala.connect(manager1).setBaseScore(newScore, wrongSecret)).to.be.revertedWith(
      'No such commitment hash'
    )
  })

  it('can decrease score after attack window and before execution window', async function () {
    await expect(upala.connect(nobody).setBaseScore(newScore, secret)).to.be.revertedWith('No such commitment hash')
    await upala.connect(manager1).setBaseScore(newScore, secret)
    const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
    expect(scoreAfter).to.eq(newScore)
  })

  it('cannot delete during attack window', async function () {
    await upala.connect(manager1).commitHash(delRootCommitHash) // +1 second to "mine" transaction
    await time.increase(attackWindow.sub(2).toNumber()) // +1s if next transaction is mined
    await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
      'Attack window is not closed yet'
    )
  })

  it('cannot delete after execution window', async function () {
    await time.increase(executionWindow.add(2).toNumber())
    await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
      'Execution window is already closed'
    )
  })
})
