/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

import "./Ibox9.sol";
import "./SafeMath.sol";

contract Box9 is Ibox9 {
    using SafeMath for uint256;

    address private admin;
    address private houseWallet;
    uint256 private houseVault;
    uint256[] private tables;
    uint256 private nextBet;
    uint256 private constant precision = 3; /* decimal places for mantissa */
    uint256 private constant referralReward = 10;
    uint256 private constant goldReward = 700;
    uint256 private constant silverReward = 125;
    uint256 private constant session = 10; /* blocks between spins */
    address private constant zeroAddress = address(0x0);

    //function Box9(address _houseWallet) public {
    function Box9() public {
        address _houseWallet = msg.sender; /* set to cunstructor arg later*/
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
        uint256 balance;
        address[] referrees;
        uint256 rewards;
        uint256[] betIds;
        uint256 totalBets;
    }

    struct Round {
        //mapping by blockHeight;
        uint256 block;
        uint256 result; // blockhash
    }

    struct Table {
        uint256 id;
        uint256 boxPrice;
        uint256 round;
        uint8[3] winningNumbers; // sorted asc
        address[] players;
        uint256 pot;
        bool closed;
        uint256[] betId; /* all bets for this table */
    }

    struct Betting {
        uint256 id;
        address player;
        uint256 round;
        uint256 tableIndex;
        uint16 boxChoice;
    }

    /* mappings */
    mapping(address => Player) private playerInfo;
    mapping(uint256 => Round) private roundInfo;
    mapping(uint256 => mapping(uint256 => Table)) private tableInfo; /* first uint is round, second is table index */
    mapping(uint256 => Betting) private betInfo;

    /* events */
    event RegisterEvent(address player, address referrer);
    event DepositEvent(address player, uint256 amount);
    event WithdrawEvent(address player, address destination, uint256 amount);
    event BetEvent(uint256 bettingId, uint256 amount);
    event WithdrawProfitsEvent(uint256 profits);

    modifier isAdmin() {
        assert(msg.sender == admin);
        _;
    }

    modifier isPlayer(address _playersAddr) {
        Player storage pl = playerInfo[_playersAddr];
        assert(pl.referrer != zeroAddress);
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
        require(pl.referrer != zeroAddress);

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
     * @param  _amount - the amount. If zero then withdraw the full balance
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
        )
    {
        Player storage pl = playerInfo[_player];

        return (pl.referrer, pl.balance, pl.rewards);
    }

    /**
     * @notice player chooses boxes (6 maximum)
     * Transaction reverts if not enough coins in his account
     * @param  _chosenBoxes - 9 lowest bits show the boxes he has chosen
     * @param  _tableId - the table
     * @return uint256 - the next blockheigh for the box spin
     */
    function chooseBoxes(uint16 _chosenBoxes, uint256 _tableId)
        external
        isPlayer(msg.sender)
        returns (uint256 round)
    {
        uint8 quantity;
        quantity = checkValidity(_chosenBoxes);
        require(quantity != 0);

        /* check if table exists */
        require(_tableId < tables.length.sub(1));
        uint256 boxprice = tables[_tableId];
        require(boxprice > 0);

        /* check if enough balance */
        Player storage pl = playerInfo[msg.sender];
        uint256 amount = quantity * boxprice;
        require(pl.balance >= amount);

        /* decrease balance */
        pl.balance = pl.balance.sub(amount);

        /* get next round */
        round = getNextRound();

        /* create bet struct , update round info */
        Betting storage bet = betInfo[nextBet];
        bet.id = nextBet;
        nextBet = nextBet.add(1);
        bet.player = msg.sender;
        bet.round = round;
        bet.tableIndex = _tableId;
        bet.boxChoice = _chosenBoxes;

        Round storage r = roundInfo[round];
        r.block = round;
        r.betId.push(bet.id);
        r.pot[_tableId] = r.pot[_tableId].add(amount);

        pl.totalBets = pl.totalBets.add(amount);

        /* emit event */
        emit BetEvent(bet.id, amount);

        return round;
    }

    /**
     * @notice shows current players and betting amounts for a table
     * @param   _blocknumber the block height of the round
     * @param  _tableId - the table id
     * @return address[] - list of all players for the round
     * @return amount - how many coins are in the pot
     */
    function currentPlayers(uint256 _blocknumber, uint256 _tableId) external returns(address[] players, uint256 amount){
        require(_tableId<tables.length);
        Table storage tbl = tableInfo[_blocknumber][_tableId];
        
        players = tbl.players;
        amount = tbl.pot;
        
        return(players, amount);
    }

    /**
     * @notice returns total coins in pool for a round
     * @param  _blocknumber - the block height of the round
     * @param  _tableId - the table id
     * @return uint256 , total coins in pool for this round
     */
    //function poolTotal(uint256 _blocknumber, uint256 _tableId) external view returns (uint256 total);

    /**
     * @notice update the smart contract's state after a round - callable by anyone
     * @param  _blocknumber the block height of the round
     *  @return uint256 - returns the blockhash or revert if it was called succesfully before
     */
    function arrangePayouts(uint256 _blocknumber)
        external
        returns (uint256 result)
    {
        /* necessary checks */
        require(_blocknumber < block.number);
        require(_blocknumber.mod(10) == 0);
        Round storage r = roundInfo[_blocknumber];
        require(r.result == 0);

        result = uint256(block.blockhash(_blocknumber));

        /* if result is zero something is very wrong
         * 256 blocks passed and noone triggered this function
         * raise status for fix
         */
        if (result != 0) {
            r.result = result;
        }
        return result;
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
        pl.balance.add(msg.value);
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
        require(pl.balance >= _amount);
        pl.balance.sub(_amount);
        _to.transfer(_amount);
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
     * @notice returns the winning boxes by blockhash
     * @param  _blockhash - the blockhash to decode
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function roundResult(uint256 _blockhash)
        internal
        pure
        returns (uint8[3] result)
    {
        uint256 mask = 0xfffffff;
        uint256[9] memory boxes;
        uint256 min;
        uint256 index;
        uint256 random = _blockhash >> 4; /* discard the last hex digit*/
        for (uint8 i = 0; i < 9; i++) {
            boxes[8 - i] = random & mask; /* get last 7 hex digits */
            random = random >> (7 * 4); /* prepare the random number for next box */
        }

        /* get the three lowest numbers */
        for (uint8 j = 0; j < 3; j++) {
            min = boxes[0];
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
     * @notice returns the winning boxes by block height
     * @param  _round - block height
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function _winningBoxes(uint256 _round)
        internal
        view
        returns (uint8[3] result)
    {
        uint256 blockhash;
        Round storage r = roundInfo[_round];
        blockhash = r.result;
        require(blockhash != 0);
        return (roundResult(blockhash));
    }

    /**
     * @notice returns the winning boxes by block height
     * @param  _round - block height
     * @return uint8[3] - returns three winning boxes by box index (first is golden)
     */
    function winningBoxes(uint256 _round)
        external
        view
        returns (uint8[3] result)
    {
        return _winningBoxes(_round);
    }

    /**
     * @notice returns block height for next round
     * @return uint256 - the block height of next spin
     */
    function getNextRound() internal view returns (uint256 blockHeight) {
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
     * @notice checks the 16bit number of box choice
     * @param _encodedNumber - the choice payload
     * @return uint16[] - returns the number of choiced boxes, zero if invalid
     */
    function checkValidity(uint16 _encodedNumber)
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
}
