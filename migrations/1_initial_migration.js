const localeLending = artifacts.require("protocol/core/LocaleLending");

module.exports = function (deployer) {
  deployer.deploy(localeLending);
};