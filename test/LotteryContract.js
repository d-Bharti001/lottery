const chai = require('chai');
const chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);
const { expect } = chai;
const config = require('../hardhat.config');

const Lottery = artifacts.require('LotteryContract');

async function wait(millis) {
  return new Promise((resolve) => {
    setTimeout(() => {resolve()}, millis);
  })
}

describe('Lottery contract', () => {
  let lottery, owner, accounts;

  before(async () => {
    lottery = await Lottery.new(
      web3.utils.toWei('0.1','ether'),
      60*60, // 1 hour
      config.networks.kovan.vrfCoordinator,
      config.networks.kovan.LINK,
      config.networks.kovan.keyHash,
      web3.utils.toBN(config.networks.kovan.fee),
    );

    await lottery.transferTokens(1);

    accounts = await web3.eth.getAccounts();
    owner = accounts[0];
    console.log('Created time:', (await lottery.createdTime()).toNumber());
    console.log('Price of ticket (in wei):', (await lottery.ticketPrice()).toString());
    console.log('Time limit (in seconds):', (await lottery.timeLimit()).toNumber());
    console.log('Address of contract:', lottery.address);
  })

  describe('Deployment', () => {
    it('Should have the right owner', async () => {
      expect(lottery.owner()).to.eventually.be.equal(owner);
    })
  })

  describe('Purchasing tickets', () => {
    it('First two accounts should be able to buy tokens', async () => {
      await expect(lottery.sendTransaction({from: accounts[0], value: web3.utils.toWei('0.1','ether')})).to.eventually.be.fulfilled;
      await expect(lottery.sendTransaction({from: accounts[1], value: web3.utils.toWei('0.1','ether')})).to.eventually.be.fulfilled;
    })
    it('Should not allow to buy ticket with a different price', async () => {
      await expect(lottery.sendTransaction({from: accounts[1], value: web3.utils.toWei('0.01','ether')})).to.eventually.be.rejected;
    })
    it('should not allow to buy tickets after time limit', async () => {
      await wait(2000);
      await expect(lottery.sendTransaction({from: accounts[1], value: web3.utils.toWei('0.1','ether')})).to.eventually.be.rejected;
    })
  })

  describe('Declaring winner', () => {
    it('Anyone can\'t declare the winner except the owner', async () => {
      await expect(lottery.declareWinner({from: accounts[1]})).to.eventually.be.rejected;
    })
    it('Owner should be able to declare winner', async () => {
      await expect(lottery.declareWinner({from: owner})).to.eventually.be.fulfilled;
      console.log(await lottery.winner());
    })
    it('Winner can\'t be re-declared', async () => {
      await expect(lottery.declareWinner({from: owner})).to.eventually.be.rejected;
    })
  })

})

