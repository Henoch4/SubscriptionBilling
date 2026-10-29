// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    bool private _nonReentrant;
    constructor() { _nonReentrant = false; }
    modifier nonReentrant() {
        require(!_nonReentrant, "ReentrancyGuard: reentrant call");
        _nonReentrant = true;
        _;
        _nonReentrant = false;
    }
}

contract SubscriptionBilling is ReentrancyGuard {
    struct Plan {
        address merchant;
        string name;
        uint256 amount;
        uint256 interval;
        uint256 subscriberCount;
        uint256 revenue;
        bool active;
    }

    struct Subscription {
        uint256 planId;
        address subscriber;
        uint256 paidUntil;
        uint256 cyclesPaid;
        bool active;
    }

    uint256 public constant FEE_BPS = 100;

    Plan[] public plans;
    Subscription[] public subscriptions;
    mapping(uint256 => uint256[]) public planSubscriptions;
    mapping(address => uint256[]) public subscriberSubscriptions;

    uint256 public totalVolume;
    uint256 public totalFees;

    event PlanCreated(uint256 indexed pid, address indexed merchant, string name, uint256 amount, uint256 interval);
    event PlanDeactivated(uint256 indexed pid);
    event Subscribed(uint256 indexed pid, uint256 indexed sid, address indexed subscriber, uint256 amount);
    event Renewed(uint256 indexed sid, address indexed subscriber, uint256 amount);
    event Cancelled(uint256 indexed sid, address indexed subscriber);

    function createPlan(string calldata name, uint256 amount, uint256 interval) external returns (uint256) {
        require(amount > 0, "Zero amount");
        require(interval > 0, "Zero interval");
        Plan storage p = plans.push();
        p.merchant = msg.sender;
        p.name = name;
        p.amount = amount;
        p.interval = interval;
        p.active = true;
        uint256 pid = plans.length - 1;
        emit PlanCreated(pid, msg.sender, name, amount, interval);
        return pid;
    }

    function _charge(Plan storage p, uint256 amount) internal {
        uint256 fee = amount * FEE_BPS / 10000;
        uint256 net = amount - fee;
        p.revenue += net;
        totalVolume += amount;
        totalFees += fee;
        payable(p.merchant).transfer(net);
    }

    function subscribe(uint256 pid) external payable nonReentrant returns (uint256) {
        Plan storage p = plans[pid];
        require(p.active, "Plan inactive");
        require(msg.value == p.amount, "Amount mismatch");
        subscriptions.push(Subscription(pid, msg.sender, block.timestamp + p.interval, 1, true));
        uint256 sid = subscriptions.length - 1;
        planSubscriptions[pid].push(sid);
        subscriberSubscriptions[msg.sender].push(sid);
        p.subscriberCount += 1;
        _charge(p, msg.value);
        emit Subscribed(pid, sid, msg.sender, msg.value);
        return sid;
    }

    function renew(uint256 sid) external payable nonReentrant {
        Subscription storage s = subscriptions[sid];
        require(s.active, "Not active");
        require(block.timestamp >= s.paidUntil, "Too early");
        Plan storage p = plans[s.planId];
        require(p.active, "Plan inactive");
        require(msg.value == p.amount, "Amount mismatch");
        s.paidUntil = block.timestamp + p.interval;
        s.cyclesPaid += 1;
        _charge(p, msg.value);
        emit Renewed(sid, msg.sender, msg.value);
    }

    function cancel(uint256 sid) external {
        Subscription storage s = subscriptions[sid];
        require(s.active, "Not active");
        require(s.subscriber == msg.sender, "Not subscriber");
        s.active = false;
        Plan storage p = plans[s.planId];
        if (p.subscriberCount > 0) p.subscriberCount -= 1;
        emit Cancelled(sid, msg.sender);
    }

    function deactivatePlan(uint256 pid) external {
        Plan storage p = plans[pid];
        require(msg.sender == p.merchant, "Merchant only");
        require(p.active, "Already inactive");
        p.active = false;
        emit PlanDeactivated(pid);
    }

    function planInfo(uint256 pid) external view returns (address merchant, string memory name, uint256 amount, uint256 interval, uint256 subs, uint256 revenue, bool active) {
        Plan storage p = plans[pid];
        return (p.merchant, p.name, p.amount, p.interval, p.subscriberCount, p.revenue, p.active);
    }

    function subscriptionInfo(uint256 sid) external view returns (uint256 planId, address subscriber, uint256 paidUntil, uint256 cycles, bool active) {
        Subscription storage s = subscriptions[sid];
        return (s.planId, s.subscriber, s.paidUntil, s.cyclesPaid, s.active);
    }

    function planCount() external view returns (uint256) { return plans.length; }
    function subscriptionCount() external view returns (uint256) { return subscriptions.length; }
}
