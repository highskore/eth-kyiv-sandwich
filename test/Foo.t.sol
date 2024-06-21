// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { SandwichAlterterUniV2Router } from "../src/SandwichAlterterUniV2Router.sol";

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FooTest is Test {
    SandwichAlterterUniV2Router internal router;
    IERC20 internal DAI;
    IERC20 internal USDC;
    address user;
    address chef;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        router = new SandwichAlterterUniV2Router(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        user = address(0x7713974908Be4BEd47172370115e8b1219F4A5f0);
        chef = address(0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B);
        vm.createSelectFork({ blockNumber: 20_141_164, urlOrAlias: "mainnet" });
        // Prank to chef
        vm.startPrank(chef);
        // Approve DAI to router
        IERC20(DAI).approve(address(router), 2 ** 256 - 1);
        // Approve USDC to router
        IERC20(USDC).approve(address(router), 2 ** 256 - 1);
        // Prank to user
        vm.startPrank(user);
        // Approve DAI to router
        IERC20(DAI).approve(address(router), 2 ** 256 - 1);
        // Approve USDC to router
        IERC20(USDC).approve(address(router), 2 ** 256 - 1);
        // Label user and chef, DAI and USDC
        vm.label(user, "user");
        vm.label(chef, "chef");
        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
        vm.label(0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5, "DAIUSDC");
    }

    function test_Sandwich_Sell_Sell_Buy() public {
        // Prank to chef
        vm.startPrank(chef);

        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(USDC);
        uint256 amountInChef1 = 50_000_000_000_000_000_000;
        uint256 amountInUser1 = 10_000_000_000_000_000_000;

        // Check amount out from DAI to USDC
        (uint256[] memory amounts,) = router.getAmountsOut(amountInChef1, path);

        // Call swap function
        (uint256[] memory returnAmounts,) = router.swap(path, amountInChef1, amounts[1]);

        DAI.transfer(user, amountInUser1);

        // Prank to user
        vm.startPrank(user);

        // Check amount out from DAI to USDC
        (amounts,) = router.getAmountsOut(amountInUser1, path);

        // Call swap function
        router.swap(path, amountInUser1, amounts[1]);

        // Prank to chef
        vm.startPrank(chef);
        path[1] = address(DAI);
        path[0] = address(USDC);

        // Check amount out from USDC to DAI
        (amounts,) = router.getAmountsOut(returnAmounts[1], path);
        path[1] = address(DAI);
        path[0] = address(USDC);

        // Call buy function
        router.buy(path, amounts[1], amounts[0]);
    }

    function test_sandwitch_buy_buy_sell() public { }
}
