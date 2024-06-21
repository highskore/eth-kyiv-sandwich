// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

// Contracts
import { ERC721Enumerable } from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// Interfaces
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";

// Libraries
import { SafeTransferLib } from "../lib/solady/src/utils/SafeTransferLib.sol";

//                                                            _
//                                                           //
//                                                          //
//                                          _______________//__
//                                        .(______________//___).
//                                        |              /      |
//                                        |. . . . . . . / . . .|
//                                        \ . . . . . ./. . . . /
//                                         |           / ___   |
//                     _.---._             |::......./../...\.:|
//                 _.-~       ~-._         |::::/::\::/:\::::::|
//             _.-~               ~-._     |::::\::/::::::X:/::|
//         _.-~                       ~---.;:::::::/::\::/:::::|
//     _.-~                                 ~\::::::n::::::::::|
//  .-~                                    _.;::/::::a::::::::/
//  :-._                               _.-~ ./::::::::d:::::::|
//  `-._~-._                   _..__.-~ _.-~|::/::::::::::::::|
//   /  ~-._~-._              / .__..--~----.YWWWWWWWWWWWWWWWP'
//  \_____(_;-._\.        _.-~_/       ~).. . \
//     /(_____  \`--...--~_.-~______..-+_______)
//   .(_________/`--...--~/    _/           /\
//  /-._     \_     (___./_..-~__.....__..-~./
//  `-._~-._   ~\--------~  .-~_..__.-~ _.-~
//      ~-._~-._ ~---------'  / .__..--~
//          ~-._\.        _.-~_/
//              \`--...--~_.-~
//               `--...--~
//
/// @title SandwichAlterterUniV2Router
/// @notice A uniswap V2 router that detects sandwich attacks and mints an NFT when you get sandwiched
contract SandwichAlterterUniV2Router is ERC721Enumerable {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev A struct holding information about ingredients in possible sandwich
    struct SandwichIngredient {
        // @dev Type of swap, true for buy, false for sell
        bool side;
        // @dev Amount of token0 in the pool before the swap
        uint256 reserve0;
        // @dev Amount of token1 in the pool before the swap
        uint256 reserve1;
        // @dev Address of the user who made the swap
        address user;
        // @dev Amount sent to the pool
        uint256 amountIn;
        // @dev Amount received from the pool
        uint256 amountOut;
    }

    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // UniSwap V2 Factory address
    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SandwichDetected(address firstUser, address secondUser, uint256 lostAmount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _factory) ERC721("Sandwich NFT", "SWNFT") {
        factory = _factory;
    }

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    // @dev Mapping to store potential sandwiches in a block
    // @dev pool => block number => SandwichIngredient[]
    mapping(address => mapping(uint256 => SandwichIngredient[])) public potentialSandwiches;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function swap(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        uint256 amountOutMin
    )
        external
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        (amounts, reserves) = getAmountsOut(amountIn, tokenA, tokenB);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        address pool = pairFor(tokenA, tokenB);
        tokenA.safeTransferFrom(msg.sender, pool, amounts[0]);
        (address input, address output) = (tokenA, tokenB);
        (address token0,) = sortTokens(input, output);
        uint256 amountOut = amounts[1];
        (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        address to = msg.sender;
        IUniswapV2Pair(pool).swap(amount0Out, amount1Out, to, new bytes(0));
        potentialSandwiches[pool][block.number].push(
            SandwichIngredient({
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
            // First potential sandwich
            SandwichIngredient memory first =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 3];
            // Second potential sandwich
            SandwichIngredient memory second =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 2];
            // Check if the first and second trades are on the same side
            if (first.side == second.side && !second.side && first.amountIn == amountOut) {
                // Get reserves from first swap
                (uint256 reserve0First, uint256 reserve1First) = (first.reserve0, first.reserve1);
                // Get the potential amount in from the second swap using reservers from the first swap
                uint256 potentialAmountIn = getAmountIn(second.amountOut, reserve0First, reserve1First);
                if (potentialAmountIn < second.amountIn) {
                    // It's a sandwich
                    emit SandwichDetected(first.user, second.user, second.amountIn - potentialAmountIn);
                    // Mint NFT to the user who got sandwiched
                    _mint(second.user, totalSupply() + 1);
                }
            }
        }
    }

    function buy(
        address tokenA,
        address tokenB,
        uint256 amountOut,
        uint256 maxAmountIn
    )
        external
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        (amounts, reserves) = getAmountsIn(amountOut, tokenA, tokenB);
        require(amounts[0] <= maxAmountIn, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        address pool = pairFor(tokenA, tokenB);
        tokenA.safeTransferFrom(msg.sender, pool, amounts[0]);
        (address input, address output) = (tokenA, tokenB);
        (address token0,) = sortTokens(input, output);
        uint256 amountIn = amounts[0];
        (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        address to = msg.sender;
        IUniswapV2Pair(pool).swap(amount0Out, amount1Out, to, new bytes(0));
        potentialSandwiches[pool][block.number].push(
            SandwichIngredient({
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
            // First potential sandwich
            SandwichIngredient memory first =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 3];
            // Second potential sandwich
            SandwichIngredient memory second =
                potentialSandwiches[pool][block.number][potentialSandwiches[pool][block.number].length - 2];
            // Check if the first and second trades are on the same side
            if (first.side == second.side && second.side && first.amountOut == amountIn) {
                // Get reserves from first swap
                (uint256 reserve0First, uint256 reserve1First) = (first.reserve0, first.reserve1);
                // Get the potential amount out from the second swap using reservers from the first swap
                uint256 potentialAmountOut = getAmountOut(second.amountIn, reserve0First, reserve1First);
                if (potentialAmountOut > second.amountOut) {
                    // It's a sandwich
                    emit SandwichDetected(first.user, second.user, potentialAmountOut - second.amountOut);
                    // Mint NFT to the user who got sandwiched
                    _mint(second.user, totalSupply() + 1);
                }
            }
        }
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
        address srcToken,
        address destToken
    )
        public
        view
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        amounts = new uint256[](2);
        (uint256 reserveIn, uint256 reserveOut) = getReserves(srcToken, destToken);
        amounts[0] = amountIn;
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
        address srcToken,
        address destToken
    )
        public
        view
        returns (uint256[] memory amounts, uint256[] memory reserves)
    {
        amounts = new uint256[](2);
        amounts[1] = amountOut;
        (uint256 reserveIn, uint256 reserveOut) = getReserves(srcToken, destToken);
        amounts[0] = getAmountIn(amounts[1], reserveIn, reserveOut);
        reserves = new uint256[](2);
        reserves[0] = reserveIn;
        reserves[1] = reserveOut;
    }
}
