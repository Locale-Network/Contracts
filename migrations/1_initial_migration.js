const localeLending = artifacts.require("LocaleLending");

module.exports = function (deployer) {
  deployer.deploy(localeLending);
};