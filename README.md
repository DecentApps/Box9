# Box 9 game
A decentralized chance game based on solidity

## Purpose
The purpose is to avoid any central authority to cheat. For that reason all random numbers are created from the current block hash. That way the games remains fair.

### Rules
- Players must register at first in the smart contract their public address. Upon registration each player can declare his referrer (another address) if he wishes. Referrers get 1% of the betting amount.
- Each round (box spin) is every ten blocks. That is about 5 minutes on average (320 seconds). For convenience we choose blocks devisable by ten. Consequently, every block after the launching of the smart contract that ends in zero is a valid round, i.e. a box spin
- There are nine boxes, enumerated from 1-9. Six are empty , two have a silver award and one a golden one. Golden award equals to 70% of the pool(total bets of the round) while silver awards hold 25% in total (that is, 12.5% each).
- Reward of each type (gold or silver) is split equally between the players who have chosen correctly. The six empty boxes carry no reward.
- The boxes are shuffled before each spin. The result is completely random. Random numbers are created from the spinning block hash of the block only. That way the system is provably fair and oracles are avoided. A detailed explanation of the random generator exists at the end of this README.
- One box equals a fixed amount of coins. The amount depends on the table (pool category).
- On different tables the price of boxes are different. Initially there would be tables of 10,50,100,500 and 1000 coins. Later the admin can decide to add more tables if many players express the will for different amounts.
- Players can bet only one box per number and maximum on 6 different numbers per round.
- As mentioned, referrer gets 1% of betting as a commission. This amount of coins isn't immediately available. It is a reward for active members, so it must be used at least once, i.e in a round and retrieved as a reward.


### Explanation of creation of random numbers

The creation of numbers must be random, converted to the desired range(1-9) with equal probability and also be easily verifiable by anyone. It must not be predictable of course and not come from outside by an oracle (because it can be manipulated). The best solution is the following.
Each block header contains a block hash. This hash has the following desirable properties:

- It is accessible directly by the Virtual Machine, so the smart contract can be extract it easily. 
- Can't be manipulated by anyone , either by a player, admin or an external source, including the staker.
- This hash is the result of the SHA-256 function , which guarantees a very high random number (of 256 bit) with equal probability. So the dice is fair in a decentralized way (no one can predict or alter the result of winning boxes).
- Also, it is easily verifiable by players (or anyone else). The verification process is the following:

* -  The verifier gets the block hash of the blockchain (for example the explorer)
* -  The hash has 64 hex digits(64x4=256 bits). He discards the last digit.
* -  From the first 63 digits he splits equally the number to 9 parts(the nine boxes).
* -  Now each part has 7 hex digits.
* - He shorts them from the lower number (closest to zero) to higher.
* - Lowest number is the gold box , second and third are the silver ones. The other boxes are all empty.

#### Example of a round result

Let's say that the player wants to verify the result of the round that just finished. We get as example the block **1346760** of main net. The steps are the following:

* -  The verifier gets the blockhash, which is **9333bd0dbf50896186a02547d4b97f7c44ad3a067ae2e76b4b9a6292ea03699b**
* -  last digit is "b", so it discard it
* -  It splits **9333bd0dbf50896186a02547d4b97f7c44ad3a067ae2e76b4b9a6292ea03699** as following:
- box 1: **9333bd0**
- box 2: **dbf5089**
- box 3: **6186a02**
- box 4: **547d4b9**
- box 5: **7f7c44a**
- box 6: **d3a067a**
- box 7: **e2e76b4**
- box 8: **b9a6292**
- box 9: **ea03699**
* - After shorting the result is the following:
- box 4: **547d4b9**
- box 3: **6186a02**
- box 5: **7f7c44a**
- box 1: **9333bd0**
- box 8: **b9a6292**
- box 6: **d3a067a**
- box 2: **dbf5089**
- box 7: **e2e76b4**
- box 9: **ea03699**
* - Lowest number wins. Consequently, **box 4** has the gold award while silver awards are in **boxes 3 and 5**.


*Licence:* Apache 2-0
