// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract CrowdFund {
    error OnlyManager();
    error CampaignEnded(uint256 campaignId);
    error CampaignNotEnded(uint256 campaignId);
    error CampaignNotBacked(uint256 campaignId);
    error CampaignSucceeded(uint256 campaignId);
    error CampaignDoesNotExist(uint256 campaignId);
    error AmountMustBeGreaterThanZero();
    error CampaignEndedOrSucceeded(uint256 campaignId);
    error CampaignNotFinishedOrSucceeded(uint256 campaignId, bool success);

    struct Campaign {
        address manager;
        uint256 id;
        string title;
        string description;
        uint256 target;
        uint256 startAt;
        uint256 deadline;
        bool finished;
        bool success;
    }

    address public owner;
    Campaign[] public campaigns;
    mapping(uint256 campaignId => uint256 balance) public campaignBalanceOf;
    mapping(address account => mapping(uint256 campaignId => uint256 balance))
        public accountBalanceOf;

    event CampaignStarted(
        address indexed manager,
        uint256 indexed id,
        string indexed title,
        string description,
        uint256 target,
        uint256 startAt,
        uint256 deadline
    );
    event CampaignCancelled(uint256 indexed campaignId);
    event Withdraw(
        uint256 indexed campaignId,
        uint256 indexed amount,
        address indexed recipient
    );
    event Refund(
        uint256 indexed campaignId,
        uint256 indexed amount,
        address indexed recipient
    );
    event Contribute(
        address indexed account,
        uint256 indexed campaignId,
        uint256 indexed amount
    );

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyManager(uint256 campaignId) {
        if (msg.sender != campaigns[campaignId].manager) {
            revert OnlyManager();
        }
        _;
    }

    function startCampaign(
        string memory title,
        string memory description,
        uint256 target,
        uint256 deadline
    ) public {
        uint256 campaignId = campaigns.length;
        campaigns.push(
            Campaign({
                manager: msg.sender,
                id: campaignId,
                title: title,
                description: description,
                target: target,
                startAt: block.timestamp,
                deadline: deadline,
                finished: false,
                success: false
            })
        );
        emit CampaignStarted(
            msg.sender,
            campaignId,
            title,
            description,
            target,
            block.timestamp,
            deadline
        );
    }

    function cancelCampaign(uint256 campaignId) public onlyManager(campaignId) {
        if (
            ((campaigns[campaignId].deadline <= block.timestamp) ||
                campaigns[campaignId].success)
        ) {
            revert CampaignEndedOrSucceeded(campaignId);
        }
        campaigns[campaignId].finished = true;
        emit CampaignCancelled(campaignId);
    }

    function withdraw(uint256 campaignId) public onlyManager(campaignId) {
        if (
            ((campaigns[campaignId].deadline <= block.timestamp) &&
                campaigns[campaignId].success) == false
        ) {
            revert CampaignNotFinishedOrSucceeded(
                campaignId,
                campaigns[campaignId].success
            );
        }
        uint256 amount = campaignBalanceOf[campaignId];

        campaignBalanceOf[campaignId] = 0;

        emit Withdraw(campaignId, amount, msg.sender);

        payable(msg.sender).transfer(amount);
    }

    function refund(uint256 campaignId) public {
        uint bal = accountBalanceOf[msg.sender][campaignId];
        if ((bal > 0) == false) {
            revert CampaignNotBacked(campaignId);
        }
        if (campaigns[campaignId].success) {
            revert CampaignSucceeded(campaignId);
        }
        if (block.timestamp < campaigns[campaignId].deadline) {
            revert CampaignNotEnded(campaignId);
        }
        accountBalanceOf[msg.sender][campaignId] = 0;
        campaignBalanceOf[campaignId] -= bal;

        emit Refund(campaignId, bal, msg.sender);

        payable(msg.sender).transfer(bal);
    }

    function contribute(uint256 campaignId, uint256 amount) public payable {
        amount = msg.value;

        if (amount <= 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (campaignId >= campaigns.length) {
            revert CampaignDoesNotExist(campaignId);
        }

        if (campaigns[campaignId].deadline <= block.timestamp) {
            revert CampaignEnded(campaignId);
        }

        accountBalanceOf[msg.sender][campaignId] += amount;
        campaignBalanceOf[campaignId] += amount;

        if (campaignBalanceOf[campaignId] >= campaigns[campaignId].target) {
            campaigns[campaignId].success = true;
        }

        emit Contribute(msg.sender, campaignId, amount);
    }
}
