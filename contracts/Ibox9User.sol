/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

interface Ibox9User {
    /**
     * @notice fallback not payable
     * don't accept deposits directly, user must call deposit()
     */
    function() external;

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
     * @return uint256 - credits
     * @return uint256 - bonuses received from referees
     * @return uint256 - total bets (on all tables)
     */
    function getPlayerInfo(address _player)
        external
        view
        returns (
            address referrer,
            uint256 credits,
            uint256 commissions,
            uint256 totalBets
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
     * @notice use a key to join the jackpot spin
     * succeeds only if there is normal bet on this round
     * @param  _tableId - the table id
     * @return round - the jackpot round
     */
    function joinJackpot(uint256 _tableId) external returns (uint256 round);

    /**
     * @notice shows current players and betting amounts for a table
     * @param   _blocknumber the block height of the round
     * @param  _tableId - the table id
     * @return address[] - list of all players for the round
     */
    function currentPlayers(uint256 _blocknumber, uint256 _tableId)
        external
        view
        returns (address[] players);

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
     * @notice returns the winning amount for an unclaimed bet
     * @param  _betId - id of the bet
     * @return uint256 - the winning amount to claim
     */
    function showUnclaimedReward(uint256 _betId)
        external
        view
        returns (uint256 amount);

    /**
     * @notice returns the winning boxes by block height
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function winningBoxes(uint256 _round, uint256 _tableId)
        external
        view
        returns (uint8[3] result);

    /**
     * @notice returns addresses of refferees
     * @param _referrer  - address of the referrer
     * @return address[] - returns the referee addresses
     */
    function showReferrees(address _referrer)
        external
        view
        returns (address[] referrees);

    /**
     * @notice returns an array of bonuses for a refferer
     * @param _referrer  - address of the referrer
     * @return uint256[] - returns the corresponding total amount of coins
     */
    function showReferralBonuses(address _referrer)
        external
        view
        returns (uint256[] totalBonus);

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
     * @notice returns round info
     * @param _round - block height
     * @return uint256 - saved blockhash
     * @return bool - true if needs fix
     */
    function getRoundInfo(uint256 _round)
        external
        view
        returns (uint256 hash, bool requireFix);

    /**
     * @notice returns jackpot info
     * @param _round - block height
     * @param _tableId - the table index
     * @return bool - false if not arranged yet
     * @return uint256 - the amount in jackpot
     * @return uint256 - how many winners
     * @return uint256 - prize amount
     */
    function getjackpotInfo(uint256 _round, uint256 _tableId)
        external
        view
        returns (
            bool status,
            uint256 potAmount,
            uint256 winners,
            uint256 prize
        );

    /**
     * @notice returns jackpot players
     * @param _round - block height
     * @param _tableId - the table index
     * @return address[] - addresses of joiners
     */
    function getjackpotJoiners(uint256 _round, uint256 _tableId)
        external
        view
        returns (address[] joiners);

    /**
     * @notice returns jackpot bet ids
     * @param _round - block height
     * @param _tableId - the table index
     * @return uint256[] - array of bet ids
     */
    function getjackpotBets(uint256 _round, uint256 _tableId)
        external
        view
        returns (uint256[] betIds);

    /**
     * @notice give winnings for a bet to the player - can be triggered only by player
     * @param _betId - the bet id
     * @return uint256 - returns the claimed amount
     */
    function claimWinnings(uint256 _betId) external returns (uint256 amount);

    /**
     * @notice gives jackpot prize to player - can be triggered only by player
     * @param _round - block height
     * @param _tableId - the table index
     * @return uint256 - returns the jackpot prize
     */
    function claimJackpotPrize(uint256 _round, uint256 _tableId)
        external
        returns (uint256 prize);

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
     * @param  _round - block height
     * @param  _tableId - table index
     * @return bool - true if table is open
     * @return uint256 - box price
     * @return uint256 - total amount in table pot
     */
    function getTableStatus(uint256 _round, uint256 _tableId)
        external
        view
        returns (
            bool status,
            uint256 boxPrice,
            uint256 potAmount
        );

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint256[3] - array of prizes, fisrt is gold
     */
    function getTablePrizes(uint256 _round, uint256 _tableId)
        external
        view
        returns (uint256[3] winningAmount);

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _round - block height
     * @param  _tableId - table index
     * @return address[] - array of addresses of table joiners
     */
    function getTableJoiners(uint256 _round, uint256 _tableId)
        external
        view
        returns (address[] players);

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _number - box number
     * @param  _tableId - table index
     * @return uint256 - the number of bettors
     * @return uint256 - coins amount
     */
    function getNumberState(uint8 _number, uint256 _tableId)
        external
        view
        returns (uint256 totalPlayers, uint256 totalBets);

    /**
     * @notice checks if a round hash is arranged (saved) or not
     * callable by anyone
     * @param  _blocknumber the block height of the round
     * @return bool - true if arranged
     */
    function isRoundArranged(uint256 _blocknumber)
        external
        view
        returns (bool arranged);

    /**
     * @notice checks if a table is arranged (updated) or not
     * callable by anyone
     * @param  _round the block height of the round
     * @param  _tableId the table index
     * @return bool - true if arranged
     */
    function isTableArranged(uint256 _round, uint256 _tableId)
        external
        view
        returns (bool arranged);

    /**
     * @notice checks if the jackpot is arranged (updated) or not
     * callable by anyone
     * @param  _round the block height of jackpot round
     * @param  _tableId the table index
     * @return bool - true if arranged
     */
    function isJTableArranged(uint256 _round, uint256 _tableId)
        external
        view
        returns (bool arranged);

    /**
     * @notice get winners addresses for a table of the last round
     * @param  _tableId - table id
     * @return address[] - address list of winners
     */
    function lastRoundWinners(uint256 _tableId)
        external
        view
        returns (address[] winners);

    /**
     * @notice get winning amounts for a table of the last round
     * @param  _tableId - table id
     * @return uint256[] - winning amount list of winners
     */
    function lastRoundAwards(uint256 _tableId)
        external
        view
        returns (uint256[] winningAmount);

    /**
     * @notice returns all betIds for unclaimed wins for a player
     * @param _player - player's address
     * @return uint256[] - returns the array for betIds that haven't been claimed yet
     */
    function getUnclaimedWinnings(address _player)
        external
        view
        returns (uint256[] betIds);

    /**
     * @notice returns all betIds for a player
     * @param _player - player's address
     * @return uint256[] - returns the array for betIds that haven't been claimed yet
     */
    function getBettingHistory(address _player)
        external
        view
        returns (uint256[] betIds);

    /**
     * @notice returns how many keys and how many more boxes are needed for next key
     * @param  _player - player's address
     * @param  _tableId - table index
     * @return uint256 - number of unused keys
     * @return uint256 - how many boxes to bet to get the next key
     */

    function getJackpotKeysInfo(address _player, uint256 _tableId)
        external
        view
        returns (uint256 keys, uint256 creditsLeftForNextKey);

    /**
     * @notice returns block height for next round (external)
     * @return uint256 - the block height of next spin
     */
    function getNextSpin() external view returns (uint256 blockHeight);

    /**
     * @notice returns block height for next jackpot(external)
     * @param _round - the next jackpot after this round
     * @return uint256 - the block height of next jackpot
     */
    function getNextJackpotSpin(uint256 _round)
        external
        pure
        returns (uint256 blockHeight);

    /* Events */
    event RegisterEvent(address player, address referrer);
    event DepositEvent(address player, uint256 amount);
    event WithdrawEvent(address player, address destination, uint256 amount);
    event BetEvent(
        uint256 bettingId,
        address player,
        uint256 round,
        uint256 _tableId,
        uint256 amount
    );
    event WithdrawProfitsEvent(uint256 profits);
    event ClaimReward(
        address winner,
        uint256 round,
        uint256 table,
        uint256 amount
    );
    event ClaimJackpotPrize(
        address winner,
        uint256 round,
        uint256 table,
        uint256 jPrize
    );
    event JoinJackpot(address player, uint256 round, uint256 betId);
}
