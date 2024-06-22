# UniswapV2Router Sandwich Alterter

Made for the ETHKyiv 2024 Hackathon:

Task:

> Develop a Uniswap router that, in the case a user is sandwiched, mints an NFT for them indicating the extent to which
> they were sandwiched. A sandwich is defined as a basic combination of swaps that occur sequentially in a block: buy1,
> buy2, sell1, or sell1, sell2, buy1, where sell2 or buy2 received less than expected. Additional methods to detect
> sandwiches will be a plus.

### Test

Run the tests:

```sh
$ forge test
```
