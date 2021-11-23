// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract LotteryContract is VRFConsumerBase {
  address public owner;
  address public winner;
  uint public createdTime;
  uint public ticketPrice;
  uint public timeLimit;

  mapping(uint => address) customers;
  uint public count;

  bytes32 internal keyHash;
  uint internal fee;
  bool internal tokenTransferred;

  event TicketPurchased (
    address indexed buyer,
    uint timestamp
  );

  event WinnerDeclared (
    address winner,
    uint index,
    uint timestamp
  );

  constructor(uint _price, uint _seconds, address _vrfCoordinator, address _link, bytes32 _keyHash, uint _fee) 
    VRFConsumerBase(_vrfCoordinator, _link) {
      owner = msg.sender;
      createdTime = block.timestamp;
      ticketPrice = _price;
      timeLimit = _seconds;
      keyHash = _keyHash;
      fee = _fee;
  }
  
  modifier onlyOwner() {
    require(msg.sender == owner, "You are not the owner.");
    _;
  }

  modifier tokenAvailable() {
    require(tokenTransferred == true, "LINK Tokens not available for the contract address");
    _;
  }

  receive() external payable tokenAvailable {
    require(block.timestamp <= createdTime + timeLimit, "Ticket buying time limit over.");
    require(msg.value == ticketPrice, "Only 0.1 ether accepted to buy a ticket.");

    customers[++count] = msg.sender;

    emit TicketPurchased(msg.sender, block.timestamp);
  }

  function transferTokens(uint _numTokens) public onlyOwner {
    require(_numTokens > 0, "Atleast 1 token is to be transferred");
    require(LINK.balanceOf(msg.sender) >= _numTokens * 10**18, "Not enough LINK available in your account");
    bool result = LINK.transfer(address(this), _numTokens);
    require(result == true);
    tokenTransferred = true;
  }

  function declareWinner() public onlyOwner returns (bytes32 requestId) {
    require(block.timestamp > createdTime + timeLimit, "Winner can only be declared once the time limit to buy tickets is over.");
    require(winner == address(0), "Winner has been declared. Can't be re-declared");
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
    return requestRandomness(keyHash, fee);
  }

  function fulfillRandomness(bytes32 /*requestId*/, uint256 randomness) internal override {
    uint randomNum = (randomness % count) + 1;
    winner = customers[randomNum];
    require(winner != address(0), "Invalid winner address chosen");
    payable(winner).transfer(address(this).balance);

    emit WinnerDeclared(winner, randomNum, block.timestamp);
  }
}
