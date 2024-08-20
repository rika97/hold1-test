// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TrainGame {
    address public owner;
    uint256 public trainCounter;
    uint256 public dailyJackpot;
    uint256 public lastResetTime;

    struct User {
        address[] friends;
        bool registered;
    }

    struct Train {
        uint256 id;
        address[] participants;
        uint256 jackpotContribution;
        uint256 startTime;
        uint256 lastDepositTime;
        bool isActive;
    }

    mapping(address => User) public users;
    mapping(uint256 => Train) public trains;

    event UserRegistered(address user);
    event FriendAdded(address user, address friend);
    event TrainStarted(uint256 trainId, address initiator);
    event TrainCompleted(uint256 trainId, bool success);
    event DailyJackpotDistributed(uint256 timestamp, uint256 distributedAmount);
    event DailyJackpotReset(uint256 timestamp, uint256 remainingJackpot);

    constructor() {
        owner = msg.sender;
        lastResetTime = block.timestamp;
    }

    // User Registration Logic
    function registerUser() external {
        require(!users[msg.sender].registered, "Already registered");
        users[msg.sender].registered = true;
        // Grant 1000 ONEs by transferring from the contract's balance
        require(address(this).balance >= 1000 ether, "Contract doesn't have enough balance");
        payable(msg.sender).transfer(1000 ether);
        emit UserRegistered(msg.sender);
    }

    // Friend Addition Logic
    function addFriend(address friend) external {
        require(users[msg.sender].registered, "Register first");
        require(users[friend].registered, "Friend must be registered");
        require(!isFriend(msg.sender, friend), "Already friends");

        users[msg.sender].friends.push(friend);
        users[friend].friends.push(msg.sender);

        // Grant 500 ONEs to both users by transferring from the contract's balance
        require(address(this).balance >= 1000 ether, "Contract doesn't have enough balance");
        payable(msg.sender).transfer(500 ether);
        payable(friend).transfer(500 ether);

        emit FriendAdded(msg.sender, friend);
    }

    function isFriend(address user, address friend) internal view returns (bool) {
        for (uint i = 0; i < users[user].friends.length; i++) {
            if (users[user].friends[i] == friend) {
                return true;
            }
        }
        return false;
    }

    // Train Start Logic
    function startTrain() external payable {
        require(users[msg.sender].registered, "Register first");
        require(msg.value > 0, "Must deposit some ONEs to start the train");

        resetDailyJackpotIfNeeded();

        trainCounter++;
        trains[trainCounter] = Train({
            id: trainCounter,
            participants: new address [],
            jackpotContribution: msg.value,
            startTime: block.timestamp,
            lastDepositTime: block.timestamp,
            isActive: true
        });

        trains[trainCounter].participants.push(msg.sender);
        dailyJackpot += msg.value;

        emit TrainStarted(trainCounter, msg.sender);
    }

    // Deposit to Train
    function depositToTrain(uint256 trainId) external payable {
        require(users[msg.sender].registered, "Register first");
        require(trains[trainId].isActive, "Train is not active");
        require(msg.value > 0, "Must deposit some ONEs");

        resetDailyJackpotIfNeeded();

        trains[trainId].jackpotContribution += msg.value;
        dailyJackpot += msg.value;
        trains[trainId].lastDepositTime = block.timestamp; // Update last deposit time

        trains[trainId].participants.push(msg.sender);

        // Check if the train should remain active
        if (block.timestamp - trains[trainId].lastDepositTime > 30 minutes) {
            trains[trainId].isActive = false;
        }
    }

    // Check Train Status
    function checkTrainStatus(uint256 trainId, uint256 currentONEPrice, uint256 previousONEPrice) external {
        require(trains[trainId].isActive, "Train is not active");

        bool isSuccess = false;
        uint256 timeElapsed = block.timestamp - trains[trainId].startTime;

        if (timeElapsed >= 1 days || currentONEPrice >= previousONEPrice * 110 / 100) {
            isSuccess = true;
        }

        trains[trainId].isActive = false;
        emit TrainCompleted(trainId, isSuccess);
    }

    // Distribute Jackpot Automatically
    function distributeJackpot() external {
        require(block.timestamp >= lastResetTime + 1 days, "It's not time to distribute the jackpot yet");

        uint256 distributedAmount = dailyJackpot * 50 / 100;
        uint256 remainingJackpot = dailyJackpot - distributedAmount;

        // Distribute 50% of the daily jackpot to random users of winning trains
        for (uint256 i = 1; i <= trainCounter; i++) {
            if (trains[i].isActive) {
                distributeJackpotForTrain(i, distributedAmount);
            }
        }

        dailyJackpot = remainingJackpot;
        lastResetTime = block.timestamp;

        emit DailyJackpotDistributed(block.timestamp, distributedAmount);
        emit DailyJackpotReset(block.timestamp, remainingJackpot);
    }

    function distributeJackpotForTrain(uint256 trainId, uint256 distributedAmount) internal {
        uint256 totalParticipants = trains[trainId].participants.length;
        if (totalParticipants == 0) return;

        uint256 reward = distributedAmount / totalParticipants;

        for (uint256 i = 0; i < totalParticipants; i++) {
            payable(trains[trainId].participants[i]).transfer(reward);
        }
    }

    // Reset Daily Jackpot
    function resetDailyJackpotIfNeeded() internal {
        if (block.timestamp >= lastResetTime + 1 days) {
            emit DailyJackpotReset(block.timestamp, dailyJackpot);

            dailyJackpot = 0;
            lastResetTime = block.timestamp;
        }
    }

    // Fallback function to accept incoming ether
    receive() external payable {}
}