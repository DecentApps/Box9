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
     * @param  _boxPrice - price in coins per box
     * @return uint256 - returns the table id
     */
    function addNewTable(uint256 _boxPrice) external returns (uint256 tableId);

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
     * @notice returns all information about a bet
     * @param  _betId - id of the bet
     * @return address - the players address
     * @return uint256 - the round number
     * @return uint256 - the table index
     * @return uint16 - the chosen numbers (encoded)
     */
    function getBetInfo(uint256 _betId)
        external
        view
        returns (
            address player,
            uint256 round,
            uint256 tableIndex,
            uint16 chosenBoxes
        );

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
     * @notice returns stastics of bonuses for a refferer
     * @param _referrer  - address of the referrer
     * @return address[], uint256[] - returns the referee addresses
     * @return uint256[] - returns the corresponding total amount of coins
     */
    function showReferralBonuses(address _referrer)
        external
        view
        returns (address[] referrees, uint256[] totalBonus);

    /**
     * @notice bonus info
     * @param  _referree - the address of referee
     * @return address, uint256 - returns the referrer address and total bonuses given to him
     */
    function bonusGiven(address _referree)
        external
        view
        returns (address referrer, uint256 amount);

    /**
     * @notice give winnings for a bet to the player - can be triggered only by player
     * @param _betId - the bet id
     * @return uint256 - returns the claimed amount
     */
    function claimWinnings(uint256 _betId) external returns (uint256 amount);

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

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _number - box number
     * @param  _tableId - table index
     * @return uint256 - the number of bettors
     * @return uint256 - coins amount
     */
    function getNumberState(uint8 _number, uint256 _tableId)
        external
        returns (uint256 totalPlayers, uint256 totalBets);

    /* Events */
    event RegisterEvent(address player, address referrer);
    event DepositEvent(address player, uint256 amount);
    event WithdrawEvent(address player, address destination, uint256 amount);
    event BetEvent(uint256 bettingId, uint256 amount);
    event WithdrawProfitsEvent(uint256 profits);
    event ClaimReward(
        address winner,
        uint256 round,
        uint256 table,
        uint256 amount
    );
}
