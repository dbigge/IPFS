pragma solidity ^0.5.12;

import "./HEX.sol";

contract HexUtilities {

    struct StakeStore {
        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;
    }

    struct DailyDataStore {
        uint72 dayPayoutTotal;
        uint72 dayStakeSharesTotal;
        uint56 dayUnclaimedSatoshisTotal;
    }

    HEX private constant hx = HEX(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39);

    uint256 private constant HEARTS_UINT_SHIFT = 72;
    uint256 private constant HEARTS_MASK = (2 << HEARTS_UINT_SHIFT) - 1;
    uint256 private constant SATS_UINT_SHIFT = 56;
    uint256 private constant SATS_MASK = (2 << SATS_UINT_SHIFT) - 1;

    function decodeDailyData(uint256 encDay)
    private
    pure
    returns (DailyDataStore memory)
    {
        uint256 v = encDay;
        uint72 payout = uint72(v & HEARTS_MASK);
        v = v >> HEARTS_UINT_SHIFT;
        uint72 shares = uint72(v & HEARTS_MASK);
        v = v >> HEARTS_UINT_SHIFT;
        uint56 sats = uint56(v & SATS_MASK);
        return DailyDataStore(payout, shares, sats);
    }

    function interestForRange(DailyDataStore[] memory dailyData, uint72 myShares)
    private
    pure
    returns (uint72)
    {
        uint256 len = dailyData.length;
        uint72 total = 0;
        for(uint256 i = 0; i < len; i++){
            total += interestForDay(dailyData[i], myShares);
        }
        return total;
    }

    function interestForDay(DailyDataStore memory dayObj, uint72 myShares)
    private
    pure
    returns (uint72)
    {
        return myShares * dayObj.dayPayoutTotal / dayObj.dayStakeSharesTotal;
    }

    function getDataRange(uint256 b, uint256 e)
    private
    view
    returns (DailyDataStore[] memory)
    {
        uint256[] memory dataRange = hx.dailyDataRange(b, e);
        uint256 len = dataRange.length;
        DailyDataStore[] memory data = new DailyDataStore[](len);
        for(uint256 i = 0; i < len; i++){
            data[i] = decodeDailyData(dataRange[i]);
        }
        return data;
    }

    function getStakeByStakeId(address addr, uint40 sid)
    private
    view
    returns (StakeStore memory)
    {

        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;

        uint256 stakeCount = hx.stakeCount(addr);
        for(uint256 i = 0; i < stakeCount; i++){
            (stakeId,
            stakedHearts,
            stakeShares,
            lockedDay,
            stakedDays,
            unlockedDay,
            isAutoStake) = hx.stakeLists(addr, i);

            if(stakeId == sid){
                return StakeStore(stakeId,
                                stakedHearts,
                                stakeShares,
                                lockedDay,
                                stakedDays,
                                unlockedDay,
                                isAutoStake);
            }
        }
    }

    function getStakeByIndex(address addr, uint256 idx)
    private
    view
    returns (StakeStore memory)
    {
        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;

        (stakeId,
            stakedHearts,
            stakeShares,
            lockedDay,
            stakedDays,
            unlockedDay,
            isAutoStake) = hx.stakeLists(addr, idx);

        return StakeStore(stakeId,
                        stakedHearts,
                        stakeShares,
                        lockedDay,
                        stakedDays,
                        unlockedDay,
                        isAutoStake);
    }

    function getLastDataDay()
    private
    view
    returns(uint256)
    {
        uint256[13] memory globalInfo = hx.globalInfo();
        uint256 lastDay = globalInfo[4];
        return lastDay;
    }

    function getInterestByStake(StakeStore memory s)
    private
    view
    returns (uint72)
    {
        uint256 b = s.lockedDay;
        uint256 e = getLastDataDay(); // ostensibly "today"

        if (b > e) {
            //not started - error
            return 0;
        } else {
            DailyDataStore[] memory data = getDataRange(b, e);
            return interestForRange(data, s.stakeShares);
        }
    }

    function getInterestByStakeId(address addr, uint40 stakeId)
    public
    view
    returns (uint72)
    {
        StakeStore memory s = getStakeByStakeId(addr, stakeId);

        return getInterestByStake(s);
    }

    function getInterestByIndex(address addr, uint256 idx)
    public
    view
    returns (uint72)
    {
        StakeStore memory s = getStakeByIndex(addr, idx);

        return getInterestByStake(s);
    }

    function getTotalValueByIndex(address addr, uint256 stakeIndex)
    public
    view
    returns (uint72)
    {
        StakeStore memory stake = getStakeByIndex(addr, stakeIndex);

        uint72 interest = getInterestByStake(stake);
        return stake.stakedHearts + interest;
    }

    function getTotalValueByStakeId(address addr, uint40 stakeId)
    public
    view
    returns (uint72)
    {
        StakeStore memory stake = getStakeByStakeId(addr, stakeId);

        uint72 interest = getInterestByStake(stake);
        return stake.stakedHearts + interest;
    }

