// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

// Libraries
import { SafeTransferLib } from "../lib/solady/src/utils/SafeTransferLib.sol";

import { console2 } from "forge-std/src/console2.sol";

// Interface for UniswapV2Pair
interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract SandwichAlterterUniV2Router {
    address public immutable factory;

    event SandwichDetected(address firstUser, address secondUser, uint256 lostAmount);
    event PotentialSandwichCooking(uint256 block);
    event PotentialSandwichs(PotentialSandwich[] sandwiches);

    using SafeTransferLib for address;

    constructor(address _factory) {
        factory = _factory;
    }

    struct PotentialSandwich {
        bool side; // false == buy, true == sell
        uint256 reserve0;
        uint256 reserve1;
        address user;
        uint256 amountIn;
        uint256 amountOut;
    }

    // Mapping of pool address to block height to array of potential sandwiches
    mapping(address => mapping(uint256 => PotentialSandwich[])) public potentialSandwiches;

    function doSandwich() public {
        // buy0 || sell0

        // buy0 || sell0

        // sell1 || buy
    }

    function swap(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin
    )
        external
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        (amounts, reserves) = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        address pool = pairFor(path[0], path[1]);
        path[0].safeTransferFrom(msg.sender, pool, amounts[0]);
        (address input, address output) = (path[0], path[1]);
        (address token0,) = sortTokens(input, output);
        uint256 amountOut = amounts[1];
        (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        address to = msg.sender;
        IUniswapV2Pair(pool).swap(amount0Out, amount1Out, to, new bytes(0));
        potentialSandwiches[pool][block.number].push(
            PotentialSandwich({
                side: true,
                reserve0: reserves[0],
                reserve1: reserves[1],
                user: msg.sender,
                amountIn: amountIn,
                amountOut: amountOut
            })
        );
        // Check for sandwich
        if (potentialSandwiches[pool][block.number].length > 2) {
            console2.log("Checking for sandwich");
            // First potential sandwich
            PotentialSandwich memory first =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 3];
            // Second potential sandwich
            PotentialSandwich memory second =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 2];
            // Check if the first and second trades are on the same side
            if (first.side == second.side && !second.side && first.amountIn == amountOut) {
                console2.log("Top bun and meat found");
                // Get reserves from first swap
                (uint256 reserve0First, uint256 reserve1First) = (first.reserve0, first.reserve1);
                // Get the potential amount in from the second swap using reservers from the first swap
                uint256 potentialAmountIn = getAmountIn(second.amountOut, reserve0First, reserve1First);
                console2.log("Potential amount in", potentialAmountIn);
                console2.log("Second amount in", second.amountIn);
                if (potentialAmountIn < second.amountIn) {
                    // It's a sandwich
                    emit SandwichDetected(first.user, second.user, second.amountIn - potentialAmountIn);
                }
            }
        }
        emit PotentialSandwichCooking(block.number);
        emit PotentialSandwichs(potentialSandwiches[pool][block.number]);
    }

    // Execute buy and check for sandwich
    function buy(
        address[] calldata path,
        uint256 amountOut,
        uint256 maxAmountIn
    )
        external
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        (amounts, reserves) = getAmountsIn(amountOut, path);
        require(amounts[0] <= maxAmountIn, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        address pool = pairFor(path[0], path[1]);
        path[0].safeTransferFrom(msg.sender, pool, amounts[0]);
        (address input, address output) = (path[0], path[1]);
        (address token0,) = sortTokens(input, output);
        uint256 amountIn = amounts[0];
        (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        address to = msg.sender;
        IUniswapV2Pair(pool).swap(amount0Out, amount1Out, to, new bytes(0));
        potentialSandwiches[pool][block.number].push(
            PotentialSandwich({
                side: false,
                reserve0: reserves[0],
                reserve1: reserves[1],
                user: msg.sender,
                amountIn: amountIn,
                amountOut: amountOut
            })
        );
        // Check for sandwich
        if (potentialSandwiches[pool][block.number].length > 2) {
            console2.log("Checking for sandwich");
            // First potential sandwich
            PotentialSandwich memory first =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 3];
            // Second potential sandwich
            PotentialSandwich memory second =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 2];
            // Check if the first and second trades are on the same side
            if (first.side == second.side && second.side && first.amountOut == amountIn) {
                console2.log("Top bun and meat found");
                // Get reserves from first swap
                (uint256 reserve0First, uint256 reserve1First) = (first.reserve0, first.reserve1);
                // Get the potential amount out from the second swap using reservers from the first swap
                uint256 potentialAmountOut = getAmountOut(second.amountIn, reserve0First, reserve1First);
                console2.log("Potential amount out", potentialAmountOut);
                console2.log("Second amount out", second.amountOut);
                if (potentialAmountOut > second.amountOut) {
                    // It's a sandwich
                    emit SandwichDetected(first.user, second.user, potentialAmountOut - second.amountOut);
                }
            }
        }
        emit PotentialSandwichCooking(block.number);
        emit PotentialSandwichs(potentialSandwiches[pool][block.number]);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + (amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    )
        public
        view
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        (uint256 reserveIn, uint256 reserveOut) = getReserves(path[0], path[1]);
        amounts[1] = getAmountOut(amounts[0], reserveIn, reserveOut);
        reserves = new uint256[](2);
        reserves[0] = reserveIn;
        reserves[1] = reserveOut;
    }

    function getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    )
        public
        view
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        (uint256 reserveIn, uint256 reserveOut) = getReserves(path[0], path[1]);
        console2.log("Amounts1", amounts[1]);
        amounts[0] = getAmountIn(amounts[1], reserveIn, reserveOut);
        console2.log("Amounts", amounts[0]);
        reserves = new uint256[](2);
        reserves[0] = reserveIn;
        reserves[1] = reserveOut;
    }
}
