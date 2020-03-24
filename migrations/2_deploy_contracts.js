const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");

module.exports = function(deployer) {
  deployer.deploy(Upala);
  deployer.deploy(FakeDai);
};