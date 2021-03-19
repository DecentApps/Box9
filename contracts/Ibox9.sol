/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

interface Ibox9 {
    /**
     * @notice fallback not payable
     * don't accept deposits directly, user must call deposit()
     */
    function() external;

    /**
     * @notice adds new table, the only difference is box price
     * only contract owner can add a table
     * @param  _box_price - price in coins per box
     * @return uint256 - returns the table id
     */
    function addNewTable(uint256 _box_price) external returns (uint256 tableId);

    /**
     * @notice withdraws all profits to cold wallet
     * callable only by admin
     * @param  _amount - the amount. If zero then withdraw the full balance
     * @return uint256 - the withdrawn profits
     */
    function withdrawProfits(uint256 _amount)
        external
        payable
        returns (uint256 profits);

    /**
     * @notice user must register a referrer first
     * or the zero address if he doesn't have one
     * Refferer can't be changed later
     * Refferer must have already been registered
     * @param  _referrer - referrer's address
     */
    function register(address _referrer) external;

    /**
     * @notice returns total coins in pool for a round
     * @param  _blocknumber - the block height of the round
     * @param  _tableId - the table id
     * @return uint256 , total coins in pool for this round
     */
    function poolTotal(uint256 _blocknumber, uint256 _tableId)
        external
        view
        returns (uint256 total);

    /**
     * @notice returns general data for a player
     * @param  _player address
     * @return address - refferer's address
     * @return uint256 - balance
     * @return uint256 - commissions
     */
    function getPlayerInfo(address _player)
        external
        view
        returns (
            address referrer,
            uint256 balance,
            uint256 commissions
        );

    /**
     * @notice player chooses boxes (6 maximum)
     * Transaction reverts if not enough coins in his account
     * @param  _chosenBoxes - 9 lowest bits show the boxes he has chosen
     * @param  _tableId - the table
     * @return uint256 - the next blockheigh for the box spin
     */
    function chooseBoxes(uint16 _chosenBoxes, uint256 _tableId)
        external
        returns (uint256 round);

    /**
     * @notice shows current players and betting amounts for a table
     * @param   _blocknumber the block height of the round
     * @param  _tableId - the table id
     * @return address[] - list of all players for the round
     * @return amount[] - amount in coins for each player
     */
    function currentPlayers(uint256 _blocknumber, uint256 _tableId)
        external
        returns (address[] players, uint256 amount);

    /**
     * @notice returns the winning boxes by block height
     * @param  _round - block height
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function winningBoxes(uint256 _round)
        external
        view
        returns (uint8[3] result);

    /**
     * @notice update the smart contract's state after a round - callable by anyone
     * @param  _blocknumber the block height of the round
     * @return bool - should return true or revert if it was called succesfully before
     */
    function giveReward(uint256 _blocknumber) external returns (bool result);

    /**
     * @notice shows the data of current rewards for a refferer
     * @param _referrer  - address of the referrer
     * @return address[], uint256[] - returns the referee addresses and corresponding total amount of coins
     */
    function showReferralRewards(address _referrer)
        external
        view
        returns (address[] referrees, uint256[] totalRewards);

    /**
     * @notice reward info
     * @param  _referree - the address of referee
     * @return address, uint256 - returns the referrer address and total rewards given to him
     */
    function referralsGiven(address _referree)
        external
        view
        returns (address referrer, uint256 amount);

    /**
     * @notice deposit ECOC
     * revert on non-register user
     */
    function deposit() external payable;

    /**
     * @notice withdraw ECOC, can be to any address
     * if zero address just return to sender
     * @param  _amount - the number of coins
     * @param  _to - receiver's address
     */
    function withdraw(address _to, uint256 _amount) external payable;

    /**
     * @notice return all table prices
     * @return uint256[] - returns the table's box prices
     */
    function showTables() external view returns (uint256[] tables);

    /* Events */
    event RegisterEvent(address player, address referrer);
    event DepositEvent(address player, uint256 amount);
    event WithdrawEvent(address player, address destination, uint256 amount);
    event BetEvent(uint256 BettingId, uint256 amount);
    event WithdrawProfitsEvent(uint256 profits);
}
