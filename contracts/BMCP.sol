//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './Lock.sol';


contract LockableToken is Lock, ERC20,Ownable {

    using SafeMath for uint256;
    
    uint256 sendPercentage=  20;
    uint256 lockPercentage = 80;
    
    
    bool private _vault1;
    bool private _vault2;
    bool private _vault3;
    bool private _vault4;
    
    
    struct vestingSchedule {
    bool isValid;               /* true if an entry exists and is valid */
    uint32 duration;            /* Duration of the vesting schedule, with respect to the grant start day, in days. */
    }
    mapping(address => vestingSchedule) private _vestingSchedules;

    
   /**
    * @dev Error messages for require statements
    */
    string internal constant ALREADY_LOCKED = 'Tokens already locked';
    string internal constant NOT_LOCKED = 'No tokens locked';
    string internal constant AMOUNT_ZERO = 'Amount can not be 0';

   /**
    * @dev constructor to mint initial tokens
    * Shall update to _mint once openzepplin updates their npm package.
    */
    
    
     constructor() ERC20("bmpc", "BMPC") public{
        _mint(msg.sender, 1000000*10**18);
    }
    

    /**
     * @dev Locks a specified amount of tokens against an address,
     * for a specified reason and time
     * @param _reason The reason to lock tokens
     * @param _amount Number of tokens to be locked
     * @param _time Lock time in seconds
     * @param _beneficiary address
     */
    function lock(bytes32 _reason, uint256 _amount, uint256 _time, address _beneficiary)
        public override onlyOwner
        returns (bool)
    {
         uint256 validUntil = now.add(_time); //solhint-disable-line
        

        // If tokens are already locked, then functions extendLock or
        // increaseLockAmount should be used to make any changes
        require(tokensLocked(_beneficiary, _reason) == 0, ALREADY_LOCKED);
        require(_amount != 0, AMOUNT_ZERO);

        if (locked[_beneficiary][_reason].amount == 0)
            lockReason[_beneficiary].push(_reason);

        transfer(address(this), _amount);

        locked[_beneficiary][_reason] = lockToken(_amount, validUntil, false);

        emit Locked(_beneficiary, _reason, _amount, validUntil);
        return true;
    }
    
    /**
     * @dev Transfers and Locks a specified amount of tokens,
     * for a specified reason and time
     * @param _beneficiary adress to which tokens are to be transfered
     * @param _reason The reason to lock tokens
     * @param _amountToSend Number of tokens to be transfered and locked
     * @param _amountToLock Number of Tokens to lock
     * @param _time Lock time in seconds
     */
    function transferWithLock(address _beneficiary, bytes32 _reason, uint256 _amountToSend, uint256 _amountToLock, uint256 _time)
        public onlyOwner
        returns (bool)
    {   
        
        uint256 validUntil = now.add(_time); //solhint-disable-line
        
        require(tokensLocked(_beneficiary, _reason) == 0, ALREADY_LOCKED);
        require(_amountToSend != 0, AMOUNT_ZERO);

        if (locked[_beneficiary][_reason].amount == 0)
            lockReason[_beneficiary].push(_reason);

        // transfer(address(this), _amount);

        // locked[_to][_reason] = lockToken(_amount, validUntil, false);
        
        //send 20% tokens to _beneficiary
        transfer(_beneficiary, _amountToSend);
        
        //locks rest 80% tokens in Contract
        transfer(address(this), _amountToLock);

        locked[_beneficiary][_reason] = lockToken(_amountToLock, validUntil, false);
        
        
        emit Locked(_beneficiary, _reason, _amountToLock, validUntil);
        return true;
    }

    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason
     *
     * @param _of The address whose tokens are locked
     * @param _reason The reason to query the lock tokens for
     */
    function tokensLocked(address _of, bytes32 _reason)
        public override onlyOwner
        view
        returns (uint256 amount)
    {
        if (!locked[_of][_reason].claimed)
            amount = locked[_of][_reason].amount;
    }
    
    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason at a specific time
     *
     * @param _of The address whose tokens are locked
     * @param _reason The reason to query the lock tokens for
     * @param _time The timestamp to query the lock tokens for
     */
    function tokensLockedAtTime(address _of, bytes32 _reason, uint256 _time)
        public override onlyOwner
        view
        returns (uint256 amount)
    {
        if (locked[_of][_reason].validity > _time)
            amount = locked[_of][_reason].amount;
    }

    /**
     * @dev Returns total tokens held by an address (locked + transferable)
     * @param _of The address to query the total balance of
     */
    function totalBalanceOf(address _of)
        public override onlyOwner
        view
        returns (uint256 amount)
    {
        amount = balanceOf(_of);

        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            amount = amount.add(tokensLocked(_of, lockReason[_of][i]));
        }   
    }    
    
    /**
     * @dev Extends lock for a specified reason and time
     * @param _reason The reason to lock tokens
     * @param _time Lock extension time in seconds
     * @param _beneficiary address of token Holder to extend Lock
     */
    function extendLock(bytes32 _reason, uint256 _time, address _beneficiary)
        public override onlyOwner
        returns (bool)
    {
        require(tokensLocked(_beneficiary, _reason) > 0, NOT_LOCKED);

        locked[_beneficiary][_reason].validity = locked[_beneficiary][_reason].validity.add(_time);

        emit Locked(_beneficiary, _reason, locked[_beneficiary][_reason].amount, locked[_beneficiary][_reason].validity);
        return true;
    }
    
    /**
     * @dev Increase number of tokens locked for a specified reason
     * @param _reason The reason to lock tokens
     * @param _amount Number of tokens to be increased
     */
    function increaseLockAmount(bytes32 _reason, uint256 _amount, address _beneficiary)
        public override onlyOwner
        returns (bool)
    {
        require(tokensLocked(_beneficiary, _reason) > 0, NOT_LOCKED);
        transfer(address(this), _amount);

        locked[_beneficiary][_reason].amount = locked[_beneficiary][_reason].amount.add(_amount);

        emit Locked(_beneficiary, _reason, locked[_beneficiary][_reason].amount, locked[_beneficiary][_reason].validity);
        return true;
    }

    /**
     * @dev Returns unlockable tokens for a specified address for a specified reason
     * @param _of The address to query the the unlockable token count of
     * @param _reason The reason to query the unlockable tokens for
     */
    function tokensUnlockable(address _of, bytes32 _reason)
        public override onlyOwner
        view
        returns (uint256 amount)
    {   
      
        if (locked[_of][_reason].validity <= now && !locked[_of][_reason].claimed) //solhint-disable-line
            amount = locked[_of][_reason].amount;
        
      
    }

    /**
     * @dev Unlocks the unlockable tokens of a specified address
     * @param _of Address of user, claiming back unlockable tokens
     */
    function unlock(address _of)
        public override onlyOwner
        returns (uint256 unlockableTokens)
    {
        uint256 lockedTokens;

        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            lockedTokens = tokensUnlockable(_of, lockReason[_of][i]);
            if (lockedTokens > 0) {
                unlockableTokens = unlockableTokens.add(lockedTokens);
                locked[_of][lockReason[_of][i]].claimed = true;
                emit Unlocked(_of, lockReason[_of][i], lockedTokens);
            }
        }  

        if (unlockableTokens > 0)
            this.transfer(_of, unlockableTokens);
    }

    /**
     * @dev Gets the unlockable tokens of a specified address
     * @param _of The address to query the the unlockable token count of
     */
    function getUnlockableTokens(address _of)
        public override onlyOwner
        view
        returns (uint256 unlockableTokens)
    {
        for (uint256 i = 0; i < lockReason[_of].length; i++) {
            unlockableTokens = unlockableTokens.add(tokensUnlockable(_of, lockReason[_of][i]));
        }  
    }
    
    

    
    
    
}