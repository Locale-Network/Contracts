const localeLending = artifacts.require("protocol/core/LocaleLendingConfig");

module.exports = function (deployer) {
  deployer.deploy(localeLending);
};