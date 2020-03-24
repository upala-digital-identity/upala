const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");
const BasicPoolFactory = artifacts.require("BasicPoolFactory");

module.exports = function(deployer) {
  deployer.deploy(BasicPoolFactory, FakeDai.address).then(() => {
    Upala.deployed().then(upala => {
        return upala.setapprovedPoolFactory(BasicPoolFactory.address, "true");
    });
});

};