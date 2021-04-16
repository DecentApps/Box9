/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

interface Ibox9Admin {
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
     * @param  _amount - the amount. If zero then withdraw all credits
     * @return uint256 - the withdrawn profits
     */
    function withdrawProfits(uint256 _amount)
        external
        payable
        returns (uint256 profits);

    /**
     * @notice update the round state if not updated on time - admin only
     * @param  _blocknumber the block height of the round
     * @param  _blockhash the correct blockhash
     * @return bool - returns true on success
     */
    function fixRound(uint256 _blocknumber, uint256 _blockhash)
        external
        returns (bool result);

    /**
     * @notice returns the withdrawable vault balance - admin only
     * @return uint256 - house balance
     */
    function checkVaultBalance() external view returns (uint256 balance);

    /**
     * @notice change the jackpot round if already passed and not updated - admin only
     * @param  _tableId the table
     */
    function fixNextJackpotRound(uint256 _tableId)
        external;

    event WithdrawProfitsEvent(uint256 profits);
}
