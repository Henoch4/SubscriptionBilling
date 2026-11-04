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
    struct Plan { address merchant;string name;uint256 amount;uint256 interval;uint256 subscriberCount;uint256 revenue;bool active; }
    struct Subscription { uint256 planId;address subscriber;uint256 paidUntil;uint256 cyclesPaid;bool active; }
    Plan[] public plans;Subscription[] public subscriptions;mapping(uint256=>uint256[]) public planSubscriptions;mapping(address=>uint256[]) public subscriberSubscriptions;
    mapping(uint256=>uint256) public cycleNet;mapping(uint256=>uint256) public cycleRecognized;mapping(uint256=>uint256) public cycleStarted;
    uint256 public constant FEE_BPS=100;uint256 public totalVolume;uint256 public totalFees;uint256 public feeBalance;address public feeRecipient;
    event PlanCreated(uint256 indexed pid,address indexed merchant,string name,uint256 amount,uint256 interval);event PlanDeactivated(uint256 indexed pid);event Subscribed(uint256 indexed pid,uint256 indexed sid,address indexed subscriber,uint256 amount);event Renewed(uint256 indexed sid,address indexed subscriber,uint256 amount);event Cancelled(uint256 indexed sid,address indexed subscriber);event SubscriptionRefunded(uint256 indexed sid,address indexed subscriber,uint256 amount);event RevenueWithdrawn(uint256 indexed pid,address indexed merchant,uint256 amount);
    constructor(){feeRecipient=msg.sender;}
    function createPlan(string calldata name,uint256 amount,uint256 interval) external returns(uint256 pid) { require(bytes(name).length>0&&bytes(name).length<=64&&amount>0&&interval>0,"Invalid plan");pid=plans.length;plans.push(Plan(msg.sender,name,amount,interval,0,0,true));emit PlanCreated(pid,msg.sender,name,amount,interval); }
    function _start(uint256 sid,uint256 amount) private { uint256 fee=amount*FEE_BPS/10000;cycleNet[sid]=amount-fee;cycleRecognized[sid]=0;cycleStarted[sid]=block.timestamp;totalVolume+=amount;totalFees+=fee;feeBalance+=fee; }
    function _accrue(uint256 sid) private { if(cycleNet[sid]==0)return;Subscription storage s=subscriptions[sid];Plan storage p=plans[s.planId];uint256 elapsed=block.timestamp-cycleStarted[sid];if(elapsed>p.interval)elapsed=p.interval;uint256 target=cycleNet[sid]*elapsed/p.interval;uint256 amount=target-cycleRecognized[sid];cycleRecognized[sid]=target;p.revenue+=amount; }
    function accrueSubscription(uint256 sid) external { _accrue(sid); }
    function _range(uint256 pid,uint256 offset,uint256 count) private { require(count<=100,"Maximum 100 per page");uint256[] storage ids=planSubscriptions[pid];require(offset<=ids.length,"Invalid offset");uint256 end=offset+count;if(end>ids.length)end=ids.length;for(uint256 i=offset;i<end;i++)_accrue(ids[i]); }
    function _withdraw(uint256 pid) private { Plan storage p=plans[pid];require(msg.sender==p.merchant,"Merchant only");uint256 amount=p.revenue;require(amount>0,"No vested revenue");p.revenue=0;(bool ok,)=msg.sender.call{value:amount}("");require(ok,"Withdraw failed");emit RevenueWithdrawn(pid,msg.sender,amount); }
    function withdrawRevenue(uint256 pid) external nonReentrant { _range(pid,0,100);_withdraw(pid); }
    function withdrawRevenueFor(uint256 pid,uint256 offset,uint256 count) external nonReentrant { _range(pid,offset,count);_withdraw(pid); }
    function subscribe(uint256 pid) external payable nonReentrant returns(uint256 sid) { Plan storage p=plans[pid];require(p.active&&msg.value==p.amount,"Plan or payment invalid");sid=subscriptions.length;subscriptions.push(Subscription(pid,msg.sender,block.timestamp+p.interval,1,true));planSubscriptions[pid].push(sid);subscriberSubscriptions[msg.sender].push(sid);p.subscriberCount++;_start(sid,msg.value);emit Subscribed(pid,sid,msg.sender,msg.value); }
    function renew(uint256 sid) external payable nonReentrant { Subscription storage s=subscriptions[sid];Plan storage p=plans[s.planId];require(s.subscriber==msg.sender&&s.active&&p.active,"Subscription unavailable");require(block.timestamp>=s.paidUntil&&msg.value==p.amount,"Renewal time or payment invalid");_accrue(sid);s.paidUntil=block.timestamp+p.interval;s.cyclesPaid++;_start(sid,msg.value);emit Renewed(sid,msg.sender,msg.value); }
    function cancel(uint256 sid) external nonReentrant { Subscription storage s=subscriptions[sid];require(s.subscriber==msg.sender&&s.active,"Not your active subscription");_accrue(sid);uint256 refund=cycleNet[sid]-cycleRecognized[sid];cycleNet[sid]=0;cycleRecognized[sid]=0;s.active=false;plans[s.planId].subscriberCount--;if(refund>0){(bool ok,)=msg.sender.call{value:refund}("");require(ok,"Refund failed");emit SubscriptionRefunded(sid,msg.sender,refund);}emit Cancelled(sid,msg.sender); }
    function getRefundable(uint256 sid) external view returns(uint256) { Subscription storage s=subscriptions[sid];if(!s.active)return 0;Plan storage p=plans[s.planId];uint256 elapsed=block.timestamp-cycleStarted[sid];if(elapsed>=p.interval)return 0;return cycleNet[sid]-cycleNet[sid]*elapsed/p.interval; }
    function deactivatePlan(uint256 pid) external { Plan storage p=plans[pid];require(p.merchant==msg.sender&&p.active,"Not your active plan");p.active=false;emit PlanDeactivated(pid); }
    function withdrawFees() external nonReentrant { require(msg.sender==feeRecipient,"Fee recipient only");uint256 amount=feeBalance;require(amount>0,"No fees");feeBalance=0;(bool ok,)=msg.sender.call{value:amount}("");require(ok,"Fee transfer failed"); }
    function planInfo(uint256 pid) external view returns(address merchant,string memory name,uint256 amount,uint256 interval,uint256 subs,uint256 revenue,bool active) { Plan storage p=plans[pid];return(p.merchant,p.name,p.amount,p.interval,p.subscriberCount,p.revenue,p.active); }
    function subscriptionInfo(uint256 sid) external view returns(uint256 planId,address subscriber,uint256 paidUntil,uint256 cycles,bool active) { Subscription storage s=subscriptions[sid];return(s.planId,s.subscriber,s.paidUntil,s.cyclesPaid,s.active); }
    function planCount() external view returns(uint256){return plans.length;}function subscriptionCount() external view returns(uint256){return subscriptions.length;}
}

