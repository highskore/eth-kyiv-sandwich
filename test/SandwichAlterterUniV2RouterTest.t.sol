// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

// Dependencies
import { Test } from "forge-std/src/Test.sol";

// Contracts
import { SandwichAlterterUniV2Router } from "../src/SandwichAlterterUniV2Router.sol";

// Interfaces
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SandwichAlterterUniV2RouterTest is Test {
    SandwichAlterterUniV2Router internal router;
    IERC20 internal dai;
    IERC20 internal usdc;
    address user;
    address chef;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        router = new SandwichAlterterUniV2Router(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        user = address(0xA10c7CE4b876998858b1a9E12b10092229539400);
        chef = address(0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B);
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        // Prank to chef
        vm.startPrank(chef);
        // Approve DAI to router
        IERC20(dai).approve(address(router), 2 ** 256 - 1);
        // Approve USDC to router
        IERC20(usdc).approve(address(router), 2 ** 256 - 1);
        // Prank to user
        vm.startPrank(user);
        // Approve DAI to router
        IERC20(dai).approve(address(router), 2 ** 256 - 1);
        // Approve USDC to router
        IERC20(usdc).approve(address(router), 2 ** 256 - 1);
        // Label user and chef, DAI and USDC
        vm.label(user, "user");
        vm.label(chef, "chef");
        vm.label(address(dai), "DAI");
        vm.label(address(usdc), "USDC");
        vm.label(0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5, "DAIUSDC");
    }

    function test_sandwich_sell_sell_buy() public {
        // Prank to chef
        vm.startPrank(chef);

        address tokenA = address(dai);
        address tokenB = address(usdc);
        uint256 amountInChef1 = 5_000_000_000_000_000_000_000_000;
        uint256 amountInUser1 = 3_000_000_000_000_000_000_000_000;

        // Check amount out from DAI to USDC
        (uint256[] memory amounts,) = router.getAmountsOut(amountInChef1, tokenA, tokenB);

        // Save initial amount out
        uint256 initialAmountOut = amounts[1];

        // Call swap function
        router.swap(tokenA, tokenB, amountInChef1, initialAmountOut);

        // Send DAI to user
        dai.transfer(user, amountInUser1);

        // Prank to user
        vm.startPrank(user);

        // Check amount out from DAI to USDC
        (amounts,) = router.getAmountsOut(amountInUser1, tokenA, tokenB);

        // Call swap function
        router.swap(tokenA, tokenB, amountInUser1, amounts[1]);

        // Prank to chef
        vm.startPrank(chef);

        // Check amount out from USDC to DAI
        (amounts,) = router.getAmountsOut(initialAmountOut, tokenB, tokenA);

        // Check DAI balance before swap
        uint256 balanceBefore = dai.balanceOf(chef);

        // Check USDC balance before swap
        uint256 balanceBeforeUSDC = usdc.balanceOf(chef);

        // Call buy function
        router.buy(tokenB, tokenA, amounts[1], amounts[0]);

        // Check DAI balance after swap
        uint256 balanceAfter = dai.balanceOf(chef);

        // Check USDC balance after swap
        uint256 balanceAfterUSDC = usdc.balanceOf(chef);

        // Make sure that the balance of DAI is increased more than amountInChef1
        assert(balanceAfter > balanceBefore + amountInChef1);

        // Make sure that the balance of USDC has decreased axactly initialAmountOut
        assert(balanceBeforeUSDC - balanceAfterUSDC == initialAmountOut);

        // Make sure NFT is minted to user
        assert(router.balanceOf(user) == 1);
    }

    function test_sandwich_buy_buy_sell() public {
        // Prank to chef
        vm.startPrank(chef);

        address tokenA = address(dai);
        address tokenB = address(usdc);
        uint256 amountInChef1 = 5_000_000_000_000_000_000_000_000;
        uint256 amountInUser1 = 3_000_000_000_000_000_000_000_000;

        // Check amount out from DAI to USDC
        (uint256[] memory amounts,) = router.getAmountsOut(amountInChef1, tokenA, tokenB);

        // Save initial amount out
        uint256 initialAmountOut = amounts[1];

        // Call swap function
        router.buy(tokenA, tokenB, initialAmountOut, amountInChef1);

        // Send DAI to user
        dai.transfer(user, amountInUser1);

        // Prank to user
        vm.startPrank(user);

        // Check amount out from DAI to USDC
        (amounts,) = router.getAmountsOut(amountInUser1, tokenA, tokenB);

        // Call swap function
        router.buy(tokenA, tokenB, amounts[1], amountInUser1);

        // Prank to chef
        vm.startPrank(chef);

        // Check amount out from USDC to DAI
        (amounts,) = router.getAmountsOut(initialAmountOut, tokenB, tokenA);

        // Check DAI balance before swap
        uint256 balanceBefore = dai.balanceOf(chef);

        // Check USDC balance before swap
        uint256 balanceBeforeUSDC = usdc.balanceOf(chef);

        // Call buy function
        router.swap(tokenB, tokenA, amounts[0], amounts[1]);

        // Check DAI balance after swap
        uint256 balanceAfter = dai.balanceOf(chef);

        // Check USDC balance after swap
        uint256 balanceAfterUSDC = usdc.balanceOf(chef);

        // Make sure that the balance of DAI is increased more than amountInChef1
        assert(balanceAfter > balanceBefore + amountInChef1);

        // Make sure that the balance of USDC has decreased axactly initialAmountOut
        assert(balanceBeforeUSDC - balanceAfterUSDC == initialAmountOut);

        // Make sure NFT is minted to user
        assert(router.balanceOf(user) == 1);
    }
}
