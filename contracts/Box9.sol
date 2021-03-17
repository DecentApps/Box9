/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

//import "./Ibox9.sol";
import "./SafeMath.sol";

contract Box9 /* is IBox9 */ {
    using SafeMath for uint256;

    address admin;
    address houseWallet;
    uint256[] tables;
    uint256 constant referralReward = 10; // 3 digits
    uint256 constant goldReward = 700; // 3 digits
    uint256 constant silverReward = 125; // 3 digits
    address zeroAddress = address(0x0);

    function Box9(address _houseWallet) public {
        admin = msg.sender;
        houseWallet = _houseWallet;

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
    }

    struct Refferer {
        uint256 rewards;
        address[] referrees;
    }

    struct Round {
        //uint256 blockHeight;
        uint256 result; // blockhash
        uint256[] pot; //for each table
        // also players with chosen boxes, table and amount
    }

    mapping(address => Player) private playerInfo;

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
     * @param  _box_price - price in coins per box
     * @return uint8 - returns the table id
     */
    function addNewTable(uint256 _box_price)
        external
        isAdmin()
        returns (uint256 tableId)
    {
        require(_box_price > 0);
        tables.push(_box_price);
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
        } else {
            /* register if referrer already registered */
            Player storage referrer = playerInfo[_referrer];
            require(referrer.referrer != zeroAddress);
            pl.referrer = _referrer;
        }
    }

    /**
     * @notice withdraws all profits to cold wallet
     * callable only by admin
     * @return uint256 - the profits
     */
    //function withdrawProfits() external payable returns(uint256 profits);

    /**
     * @notice returns total coins in pool for a round
     * @param  _blocknumber - the block height of the round
     * @param  _tableId - the table id
     * @return uint256 , total coins in pool for this round
     */
    //function poolTotal(uint256 _blocknumber, uint8 _tableId) view returns (uint256 total);

    /**
     * @notice returns useful data for a player
     * @param  _player address
     * @return ....
     */
    //function playerInfo(address _player) view returns(/* data from player struct */);

    /**
     * @notice player chooses boxes (6 maximum)
     * Transaction reverts if not enough coins in his account
     * @param  _chosenBoxes - 9 lowest bits show the boxes he has chosen
     * @param  _tableId - the table
     * @return uint256 - the next blockheigh for the box spin
     */
    //function chooseBoxes(uint16 _chosenBoxes, uint8 _tableId) external returns(uint256 round);

    /**
     * @notice shows current players and betting amounts for a table
     * @param   _blocknumber the block height of the round
     * @param  _tableId - the table id
     * @return address[] - list of all players for the round
     * @return amount[] - amount in coins for each player
     */
    //function currentPlayers(uint256 _blocknumber, uint8 _tableId) public returns(address[] players, uint256 amount);

    /**
     * @notice gets the non empty(winning) boxes for a round
     * @param   _blocknumber the block height of the round
     * @return returns the boxes encoded in an uint16 at lower bits (bitmask to decode)
     */
    //function roundResult(uint256 _blocknumber) returns (uint16 awardedBoxes);

    /**
     * @notice update the smart contract's state after a round - callable by anyone
     * @param  _blocknumber the block height of the round
     * @return bool - should return true or revert if it was called succesfully before
     */
    //function giveReward(uint256 _blocknumber) public returns (bool result);

    /**
     * @notice shows the data of current rewards for a refferer
     * @param _referrer  - address of the referrer
     * @return address[], uint256[] - returns the referee addresses and corresponding total amount of coins
     */
    //function showReferralRewards(address _referrer) external returns(address[] referrees , uint256[] totalRewards);

    /**
     * @notice reward info
     * @param  _referree - the address of referee
     * @return address, uint256 - returns the referrer address and total rewards given to him
     */
    //function referralsGiven(address _referree) external returns(address referrer, uint256 amount);

    /**
     * @notice deposit ECOC
     * revert on non-register user
     */
    //function deposit() external payable;

    /**
     * @notice withdraw ECOC, can be to any address
     * if zero address just return to sender
     * @param  _amount - the number of coins
     * @param  _to - receiver's address
     */
    //function withdraw(address _to ,uint256 _amount) external payable;

    /**
     * @notice return all table prices
     * @return uint256[] - returns the table's box prices
     */
    function showTables() public view returns (uint256[]) {
        return tables;
    }
}
