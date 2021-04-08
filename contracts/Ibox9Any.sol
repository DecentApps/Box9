/* https://www.apache.org/licenses/LICENSE-2.0 */

pragma solidity ^0.4.20;

interface Ibox9Any {
    /**
     * @notice update the smart contract's state after a round - callable by anyone
     * @param  _blocknumber the block height of the round
     * @return uint256 - returns the blockhash or revert if it was called succesfully before
     */
    function arrangeRound(uint256 _blocknumber)
        external
        returns (uint256 result);

    /**
     * @notice update table state after a round is updated - callable by anyone
     * @param  _round the block height of the round
     * @param  _tableId the block height of the round
     * @return bool - returns true on success
     */
    function arrangeTable(uint256 _round, uint256 _tableId)
        external
        returns (bool result);

    /**
     * @notice update jackpot state after a round is updated - callable by anyone
     * @param  _round the block height of the round
     * @param  _tableId the block height of the round
     */
    function arrangeJackpotTable(uint256 _round, uint256 _tableId) external;

    /**
     * @notice saving last round winners for showing purposes only
     * can be triggered by anyone, doesnt affect the player's credits
     * @param _tableId - the table
     * @return uint256 - returns the number of winners
     * @return uint256 - the total awards given
     */
    function updateLastWinners(uint256 _tableId)
        external
        returns (uint256 winners, uint256 totalAwards);

    event UpdateRoundState(uint256 blocknumber, uint256 hash);
    event UpdateTableState(uint256 blocknumber, uint256 tableIndex);
    event UpdateLastWinners(uint256 winners, uint256 totalAwards);
}
