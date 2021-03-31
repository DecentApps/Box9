/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

import "./Ibox9.sol";
import "./SafeMath.sol";

contract Box9 is Ibox9 {
    using SafeMath for uint256;

    uint256 private constant precision = 3; /* decimal places for mantissa */
    uint256 private constant rounding = 2; /* round down the number for winnings for user friendliness*/
    uint256 private constant referralReward = 10;
    uint256 private constant goldReward = 650;
    uint256 private constant silverReward = 125;
    uint256 private constant jackpotReward = 50;
    uint256 private constant jackpotKeyCost = 50; /* how many credits per key*/
    uint256 private constant session = 10; /* blocks between spins */
    uint256 private constant jackpotSession = 10000; /* blocks between jackpots */
    address private constant zeroAddress = address(0x0);

    address private admin;
    address private houseWallet;
    uint256 private houseVault;
    uint256[] private tables;
    uint256 private nextBet;

    function Box9(address _houseWallet) public {
        admin = msg.sender;
        houseWallet = _houseWallet;
        nextBet = 1;

        /* initiate tables */
        tables.push(10 * 1e8);
        tables.push(50 * 1e8);
        tables.push(100 * 1e8);
        tables.push(500 * 1e8);
        tables.push(1000 * 1e8);
    }

    struct Player {
        address referrer;
        uint256 credits;
        address[] referrees;
        uint256 rewards;
        uint256[] betIds;
        uint256 totalBets;
        uint256[] jackpotCredits;
    }

    struct Round {
        bool requireFix;
        uint256 result; /* blockhash */
    }

    struct Table {
        uint256 id;
        uint256 boxPrice;
        uint256 round;
        uint8[3] winningNumbers; /* gold, silver1, silver2 */
        uint256[3] winningAmount;
        uint256[9] boxesOnNumber;
        address[] players;
        uint256 pot;
        bool open;
        uint256[] betId; /* all bets for this table */
    }

    struct Betting {
        uint256 id;
        address player;
        uint256 round;
        uint256 tableIndex;
        uint16 boxChoice;
        bool claimed;
    }

    struct Jackpot {
        bool open;
        uint256 pot;
        address[] jPlayers;
        uint256[] betId;
    }

    struct LastResults {
        uint256 round;
        address[] lastWinners;
        uint256[] lastAwards;
    }

    /* mappings */
    mapping(address => Player) private playerInfo;
    mapping(uint256 => Round) private roundInfo; /* mapping by blockHeight; */
    mapping(uint256 => mapping(uint256 => Jackpot)) private jackpotInfo; /* first uint is round, second is table index */
    mapping(uint256 => mapping(uint256 => Table)) private tableInfo; /* first uint is round, second is table index */
    mapping(uint256 => Betting) private betInfo;
    mapping(uint256 => LastResults) private tableWinners; /* mapping by table id */

    /* events */
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
    event JoinJackpot(address player, uint256 round, uint256 betId);

    event UpdateRoundState(uint256 blocknumber, uint256 hash);
    event UpdateTableState(uint256 blocknumber, uint256 tableIndex);
    event UpdateLastWinners(uint256 winners, uint256 totalAwards);

    modifier isAdmin() {
        assert(msg.sender == admin);
        _;
    }

    modifier isPlayer(address _playersAddr) {
        Player storage pl = playerInfo[_playersAddr];
        assert(pl.referrer != zeroAddress);
        _;
    }

    modifier tableExists(uint256 _index) {
        require(_index < tables.length);
        _;
    }

    /**
     * @notice fallback not payable
     * don't accept deposits directly, user must call deposit()
     */
    function() external {}

    /**
     * @notice adds new table, the only difference is box price
     * only contract owner can add a table
     * @param  _boxPrice - price in coins per box
     * @return uint256 - returns the table id
     */
    function addNewTable(uint256 _boxPrice)
        external
        isAdmin()
        returns (uint256 tableId)
    {
        require(_boxPrice > 0);
        tables.push(_boxPrice);
        return (tables.length - 1);
    }

    /**
     * @notice user must register a referrer first
     * or the zero address if he doesn't have one
     * Refferer can't be changed later
     * Refferer must have already been registered
     * @param  _referrer - address of refferer
     */
    function register(address _referrer) external {
        Player storage pl = playerInfo[msg.sender];
        /* check if user already registered */
        require(pl.referrer == zeroAddress);

        /* check if there is a referrer*/
        if (_referrer == zeroAddress) {
            pl.referrer = houseWallet;
            emit RegisterEvent(msg.sender, zeroAddress);
        } else {
            /* register only if referrer already registered */
            Player storage referrer = playerInfo[_referrer];
            require(referrer.referrer != zeroAddress);
            pl.referrer = _referrer;
            referrer.referrees.push(msg.sender);
            emit RegisterEvent(msg.sender, _referrer);
        }
    }

    /**
     * @notice withdraws all profits to cold wallet
     * callable only by admin
     * @param  _amount - the amount. If zero then withdraw all credits
     * @return uint256 - the withdrawn profits
     */
    function withdrawProfits(uint256 _amount)
        external
        payable
        isAdmin()
        returns (uint256 profits)
    {
        require(houseVault > 0);
        if (_amount == 0) {
            profits = houseVault;
        } else {
            require(_amount <= houseVault);
            profits = _amount;
        }

        houseVault = houseVault.sub(profits);
        houseWallet.transfer(profits);

        emit WithdrawProfitsEvent(profits);

        return profits;
    }

    /**
     * @notice returns general data for a player
     * @param  _player address
     * @return address - refferer's address
     * @return uint256 - credits
     * @return uint256 - commissions
     */
    function getPlayerInfo(address _player)
        external
        view
        returns (
            address referrer,
            uint256 credits,
            uint256 commissions
        )
    {
        Player storage pl = playerInfo[_player];

        return (pl.referrer, pl.credits, pl.rewards);
    }

    /**
     * @notice returns the withdrawable vault balance - admin only
     * @return uint256 - house balance
     */
    function checkVaultBalance() external view returns (uint256 balance) {
        return houseVault;
    }

    /**
     * @notice player chooses boxes (6 maximum)
     * Transaction reverts if not enough coins in his account
     * Also, bettor opens(initiates) the table if he is the first bettor
     * @param  _chosenBoxes - 9 lowest bits show the boxes he has chosen
     * @param  _tableId - the table
     * @return uint256 - the next blockheigh for the box spin
     */
    function chooseBoxes(uint16 _chosenBoxes, uint256 _tableId)
        external
        isPlayer(msg.sender)
        returns (uint256 round)
    {
        require(_tableId < tables.length);
        uint8 quantity;
        quantity = _checkValidity(_chosenBoxes);
        require(quantity != 0);

        uint256 boxprice = tables[_tableId];
        require(boxprice > 0);

        /* check if enough credits */
        Player storage pl = playerInfo[msg.sender];
        uint256 amount = quantity * boxprice;
        require(pl.credits >= amount);

        /* get next round */
        round = _getNextRound();

        /* use bonus first */
        uint256 minR = pl.rewards;
        if (minR > amount) {
            minR = amount;
        }
        pl.rewards = pl.rewards.sub(minR);
        pl.credits = pl.credits.add(minR);

        /* decrease credits */
        pl.credits = pl.credits.sub(amount);

        /* create bet struct */
        Betting storage bet = betInfo[nextBet];
        bet.id = nextBet;
        nextBet = nextBet.add(1);
        bet.player = msg.sender;
        bet.round = round;
        bet.tableIndex = _tableId;
        bet.boxChoice = _chosenBoxes;

        _updateTableOnBet(
            msg.sender,
            round,
            _chosenBoxes,
            _tableId,
            bet.id,
            amount
        );

        pl.totalBets = pl.totalBets.add(amount);
        pl.betIds.push(bet.id);
        /* in case of new tables by admin adjust the array length accordingly */
        if (pl.jackpotCredits.length != tables.length) {
            pl.jackpotCredits.length = tables.length;
        }
        pl.jackpotCredits[_tableId] = pl.jackpotCredits[_tableId].add(quantity);

        /* give the bonus to referrer */
        uint256 bonus = amount.mul(referralReward);
        bonus = bonus.div(10**precision);
        if (pl.referrer == houseWallet) {
            houseVault = houseVault.add(bonus);
        } else {
            Player storage ref = playerInfo[pl.referrer];
            ref.rewards = ref.rewards.add(bonus);
        }

        /* emit event */
        emit BetEvent(bet.id, msg.sender, round, _tableId, amount);

        return round;
    }

    /* internal use, only for chooseBoxes() to avoid stack too deep error */
    function _updateTableOnBet(
        address _bettor,
        uint256 _round,
        uint16 _choice,
        uint256 _tableId,
        uint256 _betId,
        uint256 _amount
    ) internal {
        Table storage tbl = tableInfo[_round][_tableId];
        /* player shouldn't be able to rebet on same table and spin */
        require(!_addressExists(tbl.players, _bettor));

        if (!tbl.open) {
            /* open the table if first bettor */
            tbl.open = true;
            tbl.boxPrice = tables[_tableId];
            tbl.round = _round;
        }

        /* update table info */
        tbl.players.push(_bettor);
        tbl.betId.push(_betId);
        tbl.pot = tbl.pot.add(_amount);

        uint16 mask = 1;
        for (uint256 i = 0; i < 9; i++) {
            if (_choice & mask != 0) {
                tbl.boxesOnNumber[i] = tbl.boxesOnNumber[i].add(1);
            }
            mask = mask << 1;
        }
    }

    /**
     * @notice use a key to join the jackpot spin
     * succeeds only if there is normal bet on this round
     * @param  _tableId - the table id
     * @return round - the jackpot round
     */
    function joinJackpot(uint256 _tableId)
        external
        isPlayer(msg.sender)
        returns (uint256 round)
    {
        uint256 nRound = _getNextRound();
        uint256 jRound = _getNextJackpotRound(block.number);
        require(nRound == jRound);

        Player storage pl = playerInfo[msg.sender];
        /* in case of new tables by admin adjust the array length accordingly */
        if (pl.jackpotCredits.length != tables.length) {
            pl.jackpotCredits.length = tables.length;
        }
        require(pl.jackpotCredits[_tableId] >= jackpotKeyCost); /* reduntant check */

        pl.jackpotCredits[_tableId] = pl.jackpotCredits[_tableId].sub(
            jackpotKeyCost
        );

        Jackpot storage j = jackpotInfo[jRound][_tableId];
        j.jPlayers.push(msg.sender);
        /* get last bet for the player*/
        uint256 lastBetId = pl.betIds[pl.betIds.length.sub(1)];

        /* there must be a normal bet for this round */
        Betting storage lastBet = betInfo[lastBetId];
        require(lastBet.round == nRound);

        j.betId.push(lastBetId);

        emit JoinJackpot(msg.sender, round, lastBetId);
        round = jRound;
        return jRound;
    }

    /**
     * @notice shows current players and betting amounts for a table
     * @param   _blocknumber the block height of the round
     * @param  _tableId - the table id
     * @return address[] - list of all players for the round
     * @return amount - how many coins are in the pot
     */
    function currentPlayers(uint256 _blocknumber, uint256 _tableId)
        external
        tableExists(_tableId)
        returns (address[] players, uint256 amount)
    {
        Table storage tbl = tableInfo[_blocknumber][_tableId];

        players = tbl.players;
        amount = tbl.pot;

        return (players, amount);
    }

    /**
     * @notice returns total coins in pool for a round
     * @param  _blocknumber - the block height of the round
     * @param  _tableId - the table id
     * @return uint256 , total coins in pool for this round
     */
    function poolTotal(uint256 _blocknumber, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint256 total)
    {
        Table storage tbl = tableInfo[_blocknumber][_tableId];

        return tbl.pot;
    }

    /**
     * @notice shows the data of current rewards for a refferer
     * @param _referrer  - address of the referrer
     * @return address[], uint256[] - returns the referee addresses and corresponding total amount of coins
     */
    function showReferralBonuses(address _referrer)
        external
        view
        isPlayer(_referrer)
        returns (address[] referrees, uint256[] totalBonus)
    {
        Player memory pl = playerInfo[_referrer];
        referrees = pl.referrees;
        for (uint256 i = 0; i < referrees.length; i++) {
            Player memory ref = playerInfo[referrees[i]];
            totalBonus[i] = (ref.totalBets * referralReward) / (10**precision);
            delete ref;
        }

        return (referrees, totalBonus);
    }

    /**
     * @notice bonus info
     * @param  _referree - the address of referee
     * @return address, uint256 - returns the referrer address and total rewards given to referrer
     */
    function bonusGiven(address _referree)
        external
        view
        isPlayer(_referree)
        returns (address referrer, uint256 amount)
    {
        Player storage pl = playerInfo[_referree];
        amount = (pl.totalBets * referralReward) / (10**precision);

        return (pl.referrer, amount);
    }

    /**
     * @notice deposit ECOC
     * revert on non-register user
     */
    function deposit() external payable isPlayer(msg.sender) {
        require(msg.value > 0);

        Player storage pl = playerInfo[msg.sender];
        pl.credits = pl.credits.add(msg.value);
        emit DepositEvent(msg.sender, msg.value);
    }

    /**
     * @notice withdraw ECOC, can be to any address
     * if zero address just return to sender
     * @param  _amount - the number of coins
     * @param  _to - receiver's address
     */
    function withdraw(address _to, uint256 _amount) external payable {
        require(_amount > 0);
        Player storage pl = playerInfo[msg.sender];
        require(pl.credits >= _amount);
        /* prevent a frontend bug to send coins to zero address */

        address to = _to;
        if (_to == zeroAddress) {
            to = msg.sender;
        }

        pl.credits = pl.credits.sub(_amount);
        to.transfer(_amount);
        emit WithdrawEvent(msg.sender, _to, _amount);
    }

    /**
     * @notice return all table prices
     * @return uint256[] - returns the table's box prices
     */
    function showTables() external view returns (uint256[]) {
        return tables;
    }

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
        tableExists(_tableId)
        returns (
            bool status,
            uint256 boxPrice,
            uint256 potAmount
        )
    {
        require(_round.mod(session) == 0);
        Table storage tbl = tableInfo[_round][_tableId];
        return (tbl.open, tbl.boxPrice, tbl.pot);
    }

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint8[3] - array of winning numbers, the first is gold
     */
    function getTableResult(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint8[3] winningNumbers)
    {
        require(_round.mod(session) == 0);
        Table storage tbl = tableInfo[_round][_tableId];
        require(tbl.winningNumbers.length > 0);
        return tbl.winningNumbers;
    }

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint256[3] - array of prizes, fisrt is gold
     */
    function getTablePrizes(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint256[3] winningAmount)
    {
        require(_round.mod(session) == 0);
        Table storage tbl = tableInfo[_round][_tableId];
        require(tbl.winningAmount.length > 0);
        return tbl.winningAmount;
    }

    /**
     * @notice returns how many bettors and coins on a specific number for the next round
     * @param  _round - block height
     * @param  _tableId - table index
     * @return address[] - array of addresses of table joiners
     */
    function getTableJoiners(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (address[] players)
    {
        require(_round.mod(session) == 0);
        Table storage tbl = tableInfo[_round][_tableId];
        return tbl.players;
    }

    /**
     * @notice returns how many bettors and coins exist on a specific number for the next round
     * @param  _number - box number
     * @param  _tableId - table index
     * @return uint256 - the number of bettors
     * @return uint256 - coins amount
     */
    function getNumberState(uint8 _number, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint256 totalPlayers, uint256 totalBets)
    {
        require(_number < 9);

        uint256 round = _getNextRound();
        Table storage tbl = tableInfo[round][_tableId];
        totalPlayers = tbl.boxesOnNumber[uint256(_number)];
        totalBets = totalPlayers.mul(tbl.boxPrice);

        return (totalPlayers, totalBets);
    }

    /**
     * @notice returns the winning boxes by blockhash and table
     * @param  _blockhash - the round blockhash
     * @param  _tableId - table index
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function _roundResult(uint256 _blockhash, uint256 _tableId)
        internal
        view
        tableExists(_tableId)
        returns (uint8[3] result)
    {
        uint256 mask = 0xfffffff;
        uint256[9] memory boxes;
        uint256 min;
        uint256 index;
        /* add the table price to blockhash to make it unique for each table
           and rehash using keccak256 */
        uint256 random =
            uint256(keccak256(_blockhash + tables[_tableId].div(1e8)));

        random = random >> 4; /* discard the last hex digit*/
        for (uint8 i = 0; i < 9; i++) {
            boxes[8 - i] = random & mask; /* get last 7 hex digits */
            random = random >> (7 * 4); /* prepare the random number for next box */
        }

        /* get the three lowest numbers */
        for (uint8 j = 0; j < 3; j++) {
            min = boxes[0];
            index = 0;
            for (i = 1; i < 9; i++) {
                if (boxes[i] < min) {
                    min = boxes[i];
                    index = i;
                }
            }
            boxes[index] = uint256(-1);
            result[j] = uint8(index);
        }

        return result;
    }

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
        )
    {
        Betting storage bet = betInfo[_betId];
        /* check if bet exists */
        require(_betId == bet.id);

        player = bet.player;
        round = bet.round;
        tableIndex = bet.tableIndex;
        chosenBoxes = bet.boxChoice;

        return (player, round, tableIndex, chosenBoxes);
    }

    /**
     * @notice returns the winning boxes by block height and table
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function _winningBoxes(uint256 _round, uint256 _tableId)
        internal
        view
        tableExists(_tableId)
        returns (uint8[3] result)
    {
        uint256 blockhash;
        Round storage r = roundInfo[_round];
        blockhash = r.result;
        require(blockhash != 0);
        return (_roundResult(blockhash, _tableId));
    }

    /**
     * @notice returns the winning boxes by block height and table
     * @param  _round - block height
     * @param  _tableId - table index
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function winningBoxes(uint256 _round, uint256 _tableId)
        external
        view
        returns (uint8[3] result)
    {
        return _winningBoxes(_round, _tableId);
    }

    /**
     * @notice returns block height for next round(internal)
     * @return uint256 - the block height of next spin
     */
    function _getNextRound() internal view returns (uint256 blockHeight) {
        uint256 nextSpin;
        uint256 gap;

        nextSpin = block.number;
        gap = nextSpin.mod(session);
        if (gap == session) {
            gap = 0;
        }
        nextSpin = nextSpin.add(session - gap);
        return nextSpin;
    }

    /**
     * @notice returns block height for next round (external)
     * @return uint256 - the block height of next spin
     */
    function getNextSpin() external view returns (uint256 blockHeight) {
        return _getNextRound();
    }

    /**
     * @notice returns block height for next jackpot(internal)
     * @param _round - the next jackpot after this round
     * @return uint256 - the block height of next jackpot
     */
    function _getNextJackpotRound(uint256 _round)
        internal
        pure
        returns (uint256 blockHeight)
    {
        uint256 nextJackpotSpin;
        uint256 gap;

        nextJackpotSpin = _round;
        gap = nextJackpotSpin.mod(jackpotSession);
        if (gap == jackpotSession) {
            gap = 0;
        }
        nextJackpotSpin = nextJackpotSpin.add(jackpotSession - gap);
        return nextJackpotSpin;
    }

    /**
     * @notice returns block height for next jackpot(external)
     * @param _round - the next jackpot after this round
     * @return uint256 - the block height of next jackpot
     */
    function getNextJackpotSpin(uint256 _round)
        external
        pure
        returns (uint256 blockHeight)
    {
        return _getNextJackpotRound(_round);
    }

    /**
     * @notice checks the 16bit number of box choice
     * @param _encodedNumber - the choice payload
     * @return uint16[] - returns the number of choiced boxes, zero if invalid
     */
    function _checkValidity(uint16 _encodedNumber)
        internal
        pure
        returns (uint8 quantity)
    {
        uint8 maxQuantity = 6;
        uint16 mask = 0x8000; /* mask to set first bit */
        /* 7 most significant bits must be zero */
        for (uint8 i = 0; i < 7; i++) {
            if (_encodedNumber & mask != 0) {
                return 0;
            }
            mask = mask >> 1; /* next bit check */
        }

        /* count chosen boxes */
        for (i = 0; i < 9; i++) {
            if (_encodedNumber & mask != 0) {
                quantity++;
            }
            mask = mask >> 1; /* next bit check */
        }

        /* choice limit is 6 per round */
        if (quantity > maxQuantity) {
            return 0;
        }

        return quantity;
    }

    /**
     * @notice update the smart contract's state after a round - callable by anyone
     * @param  _blocknumber the block height of the round
     * @return uint256 - returns the blockhash or revert if it was called succesfully before
     */
    function arrangeRound(uint256 _blocknumber)
        external
        returns (uint256 result)
    {
        /* necessary checks */
        require(_blocknumber < block.number);
        require(_blocknumber.mod(session) == 0);
        Round storage r = roundInfo[_blocknumber];
        require(r.result == 0);

        result = uint256(block.blockhash(_blocknumber));

        /* if the blockhash is zero something is very wrong
         * 256 blocks passed and noone has triggered this function
         * raise status to require fix
         */
        if (result != 0) {
            r.result = result;
        } else {
            r.requireFix = true;
        }
        return result;
    }

    /**
     * @notice update the round state if not updated on time - admin only
     * @param  _blocknumber the block height of the round
     * @param  _blockhash the correct blockhash
     * @return bool - returns true on success
     */
    function fixRound(uint256 _blocknumber, uint256 _blockhash)
        external
        isAdmin()
        returns (bool result)
    {
        /* necessary checks */

        require(_blocknumber < block.number);
        require(_blocknumber.mod(session) == 0);
        Round storage r = roundInfo[_blocknumber];
        require(r.result == 0);
        require(r.requireFix);

        r.result = _blockhash;
        r.requireFix = false;
        emit UpdateRoundState(_blocknumber, _blockhash);

        return true;
    }

    /**
     * @notice update table state after a round is updated - callable by anyone
     * @param  _round the block height of the round
     * @param  _tableId the block height of the round
     * @return bool - returns true on success
     */
    function arrangeTable(uint256 _round, uint256 _tableId)
        external
        tableExists(_tableId)
        returns (bool result)
    {
        /* necessary checks */
        require(_round < block.number);
        require(_round.mod(session) == 0);
        Round storage r = roundInfo[_round];
        /* round must be updated first */
        require(r.result != 0);

        Table storage tbl = tableInfo[_round][_tableId];

        require(tbl.open == true);

        /* update winning numbers */
        tbl.winningNumbers = _winningBoxes(_round, _tableId);

        /* compute and save all rewards awards */
        uint256 jRound = _getNextJackpotRound(_round);

        Jackpot storage j = jackpotInfo[jRound][_tableId];

        uint256 capital =
            (tbl.boxesOnNumber[tbl.winningNumbers[0]] +
                tbl.boxesOnNumber[tbl.winningNumbers[1]] +
                tbl.boxesOnNumber[tbl.winningNumbers[2]])
                .mul(tbl.boxPrice);
        uint256 remaining = tbl.pot - capital;
        uint256 roundMask = 8 - rounding; /* ECOC has 8 decimals */
        uint256 award;

        if (tbl.boxesOnNumber[tbl.winningNumbers[0]] != 0) {
            award = remaining.mul(goldReward).div(10**precision);
            tbl.winningAmount[0] = award;
            tbl.winningAmount[0] = tbl.winningAmount[0].div(
                tbl.boxesOnNumber[tbl.winningNumbers[0]]
            ); /* for each gold winner */
            tbl.winningAmount[0] = _roundNumber(
                tbl.winningAmount[0],
                roundMask
            );
            tbl.pot = tbl.pot.sub(award);
        } else {
            j.pot = j.pot.add(remaining.mul(goldReward).div(10**precision));
        }

        if (tbl.boxesOnNumber[tbl.winningNumbers[1]] != 0) {
            award = remaining.mul(silverReward).div(10**precision);
            tbl.winningAmount[1] = award;
            tbl.winningAmount[1] = remaining.mul(silverReward).div(
                10**precision
            );
            tbl.winningAmount[1] = tbl.winningAmount[1].div(
                tbl.boxesOnNumber[tbl.winningNumbers[1]]
            ); /* for each silver1 winner */
            tbl.winningAmount[1] = _roundNumber(
                tbl.winningAmount[1],
                roundMask
            );
            tbl.pot = tbl.pot.sub(award);
        } else {
            j.pot = j.pot.add(remaining.mul(silverReward).div(10**precision));
        }

        if (tbl.boxesOnNumber[tbl.winningNumbers[2]] != 0) {
            award = remaining.mul(silverReward).div(10**precision);
            tbl.winningAmount[2] = award;
            tbl.winningAmount[2] = remaining.mul(silverReward).div(
                10**precision
            );
            tbl.winningAmount[2] = tbl.winningAmount[2].div(
                tbl.boxesOnNumber[tbl.winningNumbers[2]]
            ); /* for each silver2 winner */
            tbl.winningAmount[2] = _roundNumber(
                tbl.winningAmount[2],
                roundMask
            );
            tbl.pot = tbl.pot.sub(award);
        } else {
            j.pot = j.pot.add(remaining.mul(silverReward).div(10**precision));
        }

        j.pot = j.pot.add(remaining.mul(jackpotReward).div(10**precision));
        j.pot = _roundNumber(j.pot, roundMask);
        tbl.pot = tbl.pot.sub(j.pot);

        houseVault = houseVault.add(tbl.pot);
        tbl.pot = 0;
        tbl.open = false;

        return result;
    }

    /**
     * @notice rounding number by _precision digits
     * @param  _number - to be rounded
     * @param  _cut - how many digits to cut
     * @return uint256 - the _number after rounding
     */
    function _roundNumber(uint256 _number, uint256 _cut)
        internal
        pure
        returns (uint256 rounded)
    {
        rounded = _number;
        uint256 mask = 10**_cut;
        rounded = rounded.div(mask).mul(mask);
        return rounded;
    }

    /**
     * @notice saving last round winners for showing purposes only
     * can be triggered by anyone, doesnt affect the player's credits
     * @param _tableId - the table
     * @return uint256 - returns the number of winners
     * @return uint256 - the total awards given
     */
    function updateLastWinners(uint256 _tableId)
        external
        tableExists(_tableId)
        returns (uint256 winners, uint256 totalAwards)
    {
        uint256 lastRound = _getNextRound() - session;
        /* exit if already computed */
        LastResults storage tw = tableWinners[_tableId];
        require(tw.round != lastRound);

        /* initiate the structure */
        tw.round = lastRound;
        tw.lastWinners.length = 0;
        tw.lastAwards.length = 0;

        /* get all winners for the table */
        Table storage tbl = tableInfo[lastRound][_tableId]; /* use as storage to save some gas*/
        Betting storage bet;
        uint256 mask;
        uint256 amount;

        for (uint256 i = 0; i < tbl.betId.length; i++) {
            bet = betInfo[tbl.betId[i]];

            for (uint256 w = 0; w < 3; w++) {
                mask = 2**tbl.winningNumbers[w];
                if (bet.boxChoice & mask != 0) {
                    amount = amount.add(tbl.winningAmount[w]);
                }
            }
            if (amount != 0) {
                /* player won at least one prize */
                tw.lastWinners.push(bet.player);
                tw.lastAwards.push(amount);
                winners = winners.add(1);
                totalAwards = totalAwards.add(amount);
                amount = 0;
            } else {
                /* no winnings, set it to claimed to save gas for other functions */
                bet.claimed = true;
            }
        }

        emit UpdateLastWinners(winners, totalAwards);
        return (winners, totalAwards);
    }

    /**
     * @notice get winners addresses for a table of the last round
     * @param  _tableId - table id
     * @return address[] - address list of winners
     */
    function lastRoundWinners(uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (address[] winners)
    {
        LastResults memory tw = tableWinners[_tableId];
        winners = tw.lastWinners;
        return winners;
    }

    /**
     * @notice get winning amounts for a table of the last round
     * @param  _tableId - table id
     * @return uint256[] - winning amount list of winners
     */
    function lastRoundAwards(uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint256[] winningAmount)
    {
        LastResults memory tw = tableWinners[_tableId];
        winningAmount = tw.lastAwards;
        return winningAmount;
    }

    /**
     * @notice returns jackpot info
     * @param _round - block height
     * @param _tableId - the table index
     * @return bool - true if not arranged yet
     * @return uint256 - the amount in jackpot
     */
    function getjackpotInfo(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (bool status, uint256 potAmount)
    {
        Jackpot storage j = jackpotInfo[_round][_tableId];

        return (j.open, j.pot);
    }

    /**
     * @notice returns jackpot players
     * @param _round - block height
     * @param _tableId - the table index
     * @return address[] - addresses of joiners
     */
    function getjackpotJoiners(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (address[] joiners)
    {
        Jackpot storage j = jackpotInfo[_round][_tableId];

        return (j.jPlayers);
    }

    /**
     * @notice returns jackpot bet ids
     * @param _round - block height
     * @param _tableId - the table index
     * @return uint256[] - array of bet ids
     */
    function getjackpotBets(uint256 _round, uint256 _tableId)
        external
        view
        tableExists(_tableId)
        returns (uint256[] betIds)
    {
        Jackpot storage j = jackpotInfo[_round][_tableId];

        return (j.betId);
    }

    /**
     * @notice returns all betIds for unclaimed wins for a player
     * @param _player - player's address
     * @return uint256[] - returns the array for betIds that haven't been claimed yet
     */
    function getUnclaimedWinnings(address _player)
        external
        view
        isPlayer(_player)
        returns (uint256[])
    {
        Player memory pl = playerInfo[_player];
        uint256[] memory unclaimedBets = new uint256[](pl.betIds.length);
        Betting memory bet;
        uint256 index;
        for (uint256 i = 0; i < pl.betIds.length; i++) {
            bet = betInfo[pl.betIds[i]];
            if (bet.claimed) {
                continue;
            } else {
                unclaimedBets[index] = pl.betIds[i];
                index = index.add(1);
            }
        }

        uint256[] memory unclaimedBetIds = new uint256[](index);
        unclaimedBetIds = unclaimedBets;
        return unclaimedBetIds;
    }

    /**
     * @notice returns all betIds for a player
     * @param _player - player's address
     * @return uint256[] - returns the array for betIds that haven't been claimed yet
     */
    function getBettingHistory(address _player)
        external
        view
        isPlayer(_player)
        returns (uint256[] betIds)
    {
        Player memory pl = playerInfo[_player];
        betIds = pl.betIds;
        return betIds;
    }

    /**
     * @notice returns round info
     * @param _round - block height
     * @return uint256 - saved blockhash
     * @return bool - true if needs fix
     */
    function getRoundInfo(uint256 _round)
        external
        view
        returns (uint256 hash, bool requireFix)
    {
        Round storage r = roundInfo[_round];
        require(_round <= block.number);
        require(_round.mod(session) == 0);

        return (r.result, r.requireFix);
    }

    /**
     * @notice give winnings for a bet to the player - can be triggered only by player
     * @param _betId - the bet id
     * @return uint256 - returns the winning amount
     */
    function claimWinnings(uint256 _betId) external returns (uint256 amount) {
        Betting storage bet = betInfo[_betId];
        require(!bet.claimed);
        require(bet.player == msg.sender);
        require(bet.round < block.number);

        Table memory tbl = tableInfo[bet.round][bet.tableIndex];
        /* extra check, if betid exists on table */
        require(_numberExists(tbl.betId, bet.id));

        /* compute the winning amount */
        uint256 mask;
        for (uint256 w = 0; w < 3; w++) {
            mask = 2**tbl.winningNumbers[w];
            if (bet.boxChoice & mask != 0) {
                amount = amount.add(tbl.boxPrice); /* capital */
                amount = amount.add(tbl.winningAmount[w]);
            }
        }

        bet.claimed = true;
        Player storage pl = playerInfo[msg.sender];
        pl.credits = pl.credits.add(amount);

        emit ClaimReward(bet.player, bet.round, bet.tableIndex, amount);
        return amount;
    }

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
        isPlayer(_player)
        tableExists(_tableId)
        returns (uint256 keys, uint256 creditsLeftForNextKey)
    {
        Player storage pl = playerInfo[_player];
        keys = pl.jackpotCredits[_tableId].div(jackpotKeyCost);
        creditsLeftForNextKey = jackpotKeyCost.sub(
            pl.jackpotCredits[_tableId].mod(jackpotKeyCost)
        );
        if (creditsLeftForNextKey == 0) {
            creditsLeftForNextKey = jackpotKeyCost;
        }

        return (keys, creditsLeftForNextKey);
    }

    /**
     * @notice search adddress in array
     * @param _array - array to be searched
     * @param _value - the element
     * @return bool - returns true if exists, else false
     */
    function _addressExists(address[] _array, address _value)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _value) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice search integer in array
     * @param _array - array to be searched
     * @param _value - the element
     * @return bool - returns true if exists, else false
     */
    function _numberExists(uint256[] _array, uint256 _value)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _value) {
                return true;
            }
        }
        return false;
    }
}
