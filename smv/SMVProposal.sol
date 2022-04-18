pragma ton-solidity >=0.54.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "Libraries/SMVErrors.sol";
import "External/tip3/interfaces/ITokenRoot.sol";

import "Interfaces/ISMVClient.sol";
import "Interfaces/ISMVProposal.sol";
import "Interfaces/IVotingResultRecipient.sol";

import "LockableBase.sol";


/* function amount_locked () virtual internal view returns(uint128);
function performAction (uint128 amountToLock, TvmCell inputCell) virtual external;
function onCodeUpgrade (uint256 _platform_id, uint128 amountToLock, TvmCell staticCell, TvmCell inputCell) virtual internal;
function getLockedAmount () virtual external view  responsible returns(uint128);
 */

abstract contract SMVProposalBase is LockableBase, ISMVProposal {

uint256 public propId;
uint32   creationTime;
address  tokenRoot;

TvmCell propData;
uint32 startTime;
uint32 finishTime;
optional (address) notificationAddress;

uint128 public votesYes;
uint128 public votesNo;
optional (bool) public votingResult;
uint128 public amountLocked;
bool public proposalBusy;
bool public proposalPerformed;

function amount_locked () internal override view returns(uint128)
{
    return amountLocked;
}

function calcExternalClientAddress (address _tokenLocker, uint256 _platform_id) internal view returns(uint256)
{
  TvmCell dataCell = tvm.buildDataInit ( {contr:LockerPlatform,
                                          varInit:{
                                             tokenLocker: _tokenLocker,
                                             platform_id: _platform_id } } );
  uint256 dataHash = tvm.hash (dataCell);
  uint16 dataDepth = dataCell.depth();

  uint256 add_std_address = tvm.stateInitHash (platformCodeHash, dataHash , platformCodeDepth, dataDepth);
  return add_std_address ;
}

modifier check_external_client (address _tokenLocker, uint256 _platform_id) {
  uint256 expected = calcExternalClientAddress (_tokenLocker, _platform_id);
  require ( msg.sender.value == expected, SMVErrors.error_not_my_external_client) ;
  _ ;
}

modifier check_token_root {
    require ( msg.sender == tokenRoot, SMVErrors.error_not_my_token_root) ;
    _ ;
}

function onCodeUpgrade (uint256 _platform_id, uint128 amountToLock, TvmCell staticCell, TvmCell inputCell) internal override
{
    tvm.resetStorage();

    initialized = true;
    votingResult.reset();
    leftBro.reset();
    rightBro.reset();
    currentHead.reset();
    platform_id = _platform_id;
    amountLocked = amountToLock;
    proposalBusy = false;
    proposalPerformed = false;

    ( , tokenLocker , propId, platformCodeHash, platformCodeDepth) = staticCell.toSlice().decode(uint8, address, uint256, uint256, uint16);

    TvmSlice s = inputCell.toSlice();
    TvmSlice s1 = s.loadRefAsSlice(); //inputCell+currentHead

    propData = s1.loadRef();
    TvmSlice s12 = s1.loadRefAsSlice();
    (startTime, finishTime, notificationAddress, tokenRoot) = s12.decode(uint32, uint32, address, address);

    currentHead = s.decode(optional(address));

    //tvm.rawReserve(SMVConstants.PROPOSAL_INIT_VALUE, 2);
    //ISMVTokenLocker(tokenLocker).onClientCompleted {value:0, flag:128} (platform_id, true, address(this));

    uint128 extra = 0;
    if (address(this).balance > SMVConstants.PROPOSAL_INIT_VALUE)
        {extra = address(this).balance - SMVConstants.PROPOSAL_INIT_VALUE;}

    if (extra == 0 )
    {
        ISMVTokenLocker(tokenLocker).onClientCompleted {value:0, flag:128+32} (platform_id, false, address(this));
    }
    else
    {
        ISMVTokenLocker(tokenLocker).onInitialized {value: SMVConstants.EPSILON_FEE, flag: 1} (platform_id);
    }
}

function continueLeftBro() private
{
    if (!isTail())
    {
        LockableBase(rightBro.get()).setLeftBro {value: SMVConstants.ACTION_FEE, flag: 1, callback: SMVProposalBase.onSetLeftBro} (platform_id, leftBro);
    }
    else do_action();
}

function onSetRightBro (uint256 _platform_id) external check_client(_platform_id)
{
    continueLeftBro();
}

function onSetLeftBro (uint256 _platform_id) external check_client(_platform_id)
{
    do_action();
}

function do_action() private
{
    leftBro.reset();
    rightBro.reset();

    if (currentHead.hasValue()) {
        uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE, SMVConstants.ACTION_FEE);
        LockableBase(currentHead.get()).insertClient {value:extra, flag:1} (platform_id, address(this), amount_locked());
    }
    else
    {
        currentHead.set(address(this));
        uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE, SMVConstants.ACTION_FEE);
        ISMVTokenLocker(tokenLocker).onClientCompleted {value: extra, flag:1} (platform_id, true, address(this));
    }
}

function performAction (uint128 amountToLock, uint128 total_votes, TvmCell /* inputCell */) external override check_locker
{
    require(!proposalPerformed, SMVErrors.error_proposol_already_performed);
    require(initialized, SMVErrors.error_not_initialized);
    //require(now < propFinishTime, SMVErrors.error_proposal_ended);
    require(address(this).balance >= SMVConstants.PROPOSAL_MIN_BALANCE +
                                     SMVConstants.VOTING_FEE+
                                     SMVConstants.ACTION_FEE, SMVErrors.error_balance_too_low);
    require(amountToLock + amount_locked() <= total_votes, SMVErrors.error_not_enough_votes);                                 
    tvm.accept();

    proposalPerformed = true;

    if (!isHead())
    {
        LockableBase(leftBro.get()).setRightBro {value: SMVConstants.ACTION_FEE, flag: 1, callback: SMVProposalBase.onSetRightBro} (platform_id, rightBro);
    }
    else continueLeftBro();

}

function getInitialize(address _tokenLocker, uint256 _platform_id) external override check_external_client(_tokenLocker, _platform_id)
{
    require(msg.value >= SMVConstants.PROP_INITIALIZE_FEE, SMVErrors.error_balance_too_low);
    //require(!proposalBusy, SMVErrors.proposal_is_busy);
    tvm.accept();

    bool allowed = (!proposalBusy) && (now >= startTime) &&  (now < finishTime) && (!votingResult.hasValue());

    if (!allowed)
        ISMVClient(currentCaller).initialize {value:0, flag: 64} (false, finishTime);
    else {
        proposalBusy = true;
        currentCaller = msg.sender;
        ITokenRoot(tokenRoot).totalSupply {value: 0, flag: 64, callback:SMVProposalBase.onContinueInitialize} ();
    }
}

function onContinueInitialize(uint128 t) external check_token_root
{
    tryEarlyComplete(t);

    bool allowed = !votingResult.hasValue();

    if (!currentCaller.isStdZero()) {
        ISMVClient(currentCaller).initialize {value:0, flag: 64} (allowed, finishTime);
    }

    proposalBusy = false;
    currentCaller = address.makeAddrNone();
}


function onContinueVoting(uint128 t) external check_token_root
{
    tryEarlyComplete(t);

    if (votingResult.hasValue()) {
        if (!currentCaller.isStdZero()) {
            ISMVClient(currentCaller).onProposalVoted {value:0, flag: 64} (false);
        }
    }
    else
    {
        if (currentChoice)
        {
            votesYes += currentAmount;
        }
        else
        {
            votesNo += currentAmount;
        }

        if (!currentCaller.isStdZero()) {
            ISMVClient(currentCaller).onProposalVoted {value:0, flag: 64} (true);
        }
    }

    proposalBusy = false;
    currentCaller = address.makeAddrNone();
    currentAmount = 0;
}

function vote (address _locker, uint256 _platform_id, bool choice, uint128 amount) external override responsible check_external_client(_locker,_platform_id) returns(bool)
{
    require(msg.value >= SMVConstants.PROPOSAL_VOTING_FEE, SMVErrors.error_balance_too_low);
    //require(!proposalBusy, SMVErrors.proposal_is_busy);
    //require(!votingResult.hasValue(), SMVErrors.proposal_is_completed);
    tvm.accept();

    if ((proposalBusy) || (now < startTime) || (now >= finishTime) || (votingResult.hasValue()) )
        return {value:0, flag: 64} false;

    proposalBusy = true;
    currentCaller = msg.sender;
    currentAmount = amount;
    currentChoice = choice;
    ITokenRoot(tokenRoot).totalSupply {value: 0, flag: 64, callback:SMVProposalBase.onContinueVoting} ();
}

function completeVoting (uint128 t) external check_token_root
{
    if (now < finishTime)
    {
        tryEarlyComplete(t);
    }
    else
    {
        calcVotingResult(t);
    }

    if (!currentCaller.isStdZero())
    {
        IVotingResultRecipient(currentCaller).isCompletedCallback {value:0, flag: 64} (votingResult);
    }

    currentCaller = address.makeAddrNone();
    proposalBusy = false;
}

address currentCaller;
uint128 currentAmount;
bool currentChoice;


function isCompleted () override external responsible returns (optional (bool))
{
    //require (msg.value > SMVConstants.VOTING_COMPLETION_FEE, SMVErrors.error_balance_too_low);
    //require(!proposalBusy, SMVErrors.proposal_is_busy);

    if ((msg.value <= SMVConstants.VOTING_COMPLETION_FEE) || (proposalBusy))
        return {value:0, flag: 64} votingResult;

    optional (bool) empty;

    if (now < startTime)
        return {value:0, flag: 64} empty;

    if (!votingResult.hasValue())
    {
        currentCaller = msg.sender;
        proposalBusy = true;
        ITokenRoot(tokenRoot).totalSupply {value: 0, flag: 64, callback: SMVProposalBase.completeVoting} ();
    }
    else {
        return {value:0, flag: 64} votingResult;
    }
}

function _isCompleted () public view returns (optional (bool))
{
    return votingResult;
}

function isInitialized () external override view responsible check_locker returns(uint256)
{
    /* if (initialized)
        return {value:0, flag: 64} platform_id; */
    revert();    
}

function tryEarlyComplete (uint128 t) internal virtual {}
function calcVotingResult (uint128 t) internal virtual {}

function continueUpdateHead (uint256 _platform_id) external override check_client(_platform_id)
{
    leftBro.reset();
    uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE , SMVConstants.ACTION_FEE);

    ISMVProposal(address(this)).isCompleted {value: extra, 
                                              flag: 1 + 2, 
                                              callback: SMVProposalBase.onProposalCompletedWhileUpdateHead} ();
}


function onProposalCompletedWhileUpdateHead (optional (bool) completed) external check_myself
{   
    if (completed.hasValue())
    {
        if (rightBro.hasValue())
        {
            uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE, SMVConstants.ACTION_FEE);
            LockableBase(rightBro.get()).continueUpdateHead {value: extra, flag: 1} (platform_id);
            //selfdestruct(smvAccount);
        }
        else
        {
            uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE, SMVConstants.ACTION_FEE);
            optional (address) empty;
            ISMVTokenLocker(tokenLocker).onHeadUpdated {value:extra, flag:1} (platform_id, empty);
        }
    }
    else
    {
        uint128 extra = _reserve (SMVConstants.PROPOSAL_MIN_BALANCE, SMVConstants.ACTION_FEE);
        ISMVTokenLocker(tokenLocker).onHeadUpdated {value:extra, flag:1} (platform_id, address(this));
    }
}

function updateHead() external override check_locker()
{
    require(isHead(), SMVErrors.error_i_am_not_head);
    require(address(this).balance >= SMVConstants.PROPOSAL_MIN_BALANCE +
                                     SMVConstants.VOTING_COMPLETION_FEE +                               
                                     3*SMVConstants.ACTION_FEE, SMVErrors.error_balance_too_low);
    require(!proposalBusy, SMVErrors.error_proposal_is_busy);

    SMVProposalBase(address(this)).isCompleted {value: SMVConstants.VOTING_COMPLETION_FEE + SMVConstants.ACTION_FEE, 
                                                 flag: 1, 
                                                 callback: SMVProposalBase.onProposalCompletedWhileUpdateHead} ();

}

}

contract SMVProposal is SMVProposalBase {

function tryEarlyComplete (uint128 t) internal override
{
  uint128 y = votesYes;
  uint128 n = votesNo;
  if (2 * y > t) { votingResult.set(true) ; } else
    if (2 * n > t) { votingResult.set(false) ; }
}

function calcVotingResult (uint128 t) internal override
{
    uint128 y = votesYes;
    uint128 n = votesNo;
    votingResult.set(y >= 1 + (t/10) + ((n*((t/2)-(t/10)))/(t/2)));
}

}
