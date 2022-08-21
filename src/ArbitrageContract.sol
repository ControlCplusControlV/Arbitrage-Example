pragma solidity 0.8.16;

import "./interfaces/ISushi.sol";
import "./interfaces/IERC20.sol";

contract ArbitrageContract {
    // One of the best once said that Smart Contracts are like Sushi, and require care as such. This one follows that motto,
    // like a roll of Sushi at an expensive restaraunt, it has taken great care to take your money from you

    /* Flashswap Arbitrage is a bit weird, but here is how it goes

		1. Take in amountIn and OneToTwo, in addition to a target pool, and a true pool, which we will arb against
		2. Flashloan amountIn from true pool, trading it into target pool
		3. Repay amount from target pool minus profit to true LP

	*/

    address immutable UNIFACTORY;
    address immutable SUSHIROUTER;
    uint256 constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    constructor(address factory, address router) {
        UNIFACTORY = factory;
        SUSHIROUTER = router;
    }

    function arbitrageMarket(address true_pool, uint256 amountIn) external payable {
        bool OneToTwo;
        uint256 repay;
        assembly {
            mstore(0x69, 0x0902f1ac)

            pop(call(gas(), true_pool, 0, 0x85, 0x4, 0x69, 0x40))

            let reserve0 := mload(0x69)
            let reserve1 := mload(0x89)

            let k := mul(reserve0, reserve1)

            let new_r0 := 0

            // Instead of doing an overflow check at each operation
            // I just didn't so either use Yul+ where it is is safe, or do a specific check

            OneToTwo := callvalue()

            if OneToTwo { new_r0 := sub(reserve0, amountIn) }
            // pseudo - else
            if iszero(OneToTwo) { new_r0 := sub(reserve1, amountIn) }

            let new_r1 := div(k, new_r0)

            if OneToTwo { repay := div(mul(sub(new_r1, reserve1), 1000), 994) }
            // pseudo - else
            if iszero(OneToTwo) { repay := div(mul(sub(new_r1, reserve0), 1000), 994) }
        }

        bytes memory data = abi.encode(repay);

        if (OneToTwo) {
            // Flashloan A so we can repay in B
            SushiPair(true_pool).swap(amountIn, 0, address(this), data);
        } else {
            // Flashloan B so we can repay in A
            SushiPair(true_pool).swap(0, amountIn, address(this), data);
        }
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // There are probably cheaper ways but in general not worth wasting security
        address token0 = SushiPair(msg.sender).token0(); // fetch the address of token0
        address token1 = SushiPair(msg.sender).token1(); // fetch the address of token1

        require(msg.sender == SushiFactory(UNIFACTORY).getPair(token0, token1)); // ensure that msg.sender is a V2 pair
        require(sender == address(this));

        (uint256 repay) = abi.decode(data, (uint256));

        // Maybe make this a router call?
        if (amount0 == 0) {
            // Trade A into B
            ERC20(token1).approve(SUSHIROUTER, MAX_UINT);

            address[] memory route = new address[](2);

            route[0] = token1;
            route[1] = token0;

            uint256[] memory tokensOut =
                SushiRouter(SUSHIROUTER).swapExactTokensForTokens(amount1, 0, route, address(this), MAX_UINT);

            require(tokensOut[1] - repay > 0); // ensure profit is there

            ERC20(token0).transfer(msg.sender, repay);
        } else {
            // Trade B into A
            ERC20(token0).approve(SUSHIROUTER, MAX_UINT);

            address[] memory route = new address[](2);
            route[0] = token0;
            route[1] = token1;

            uint256[] memory tokensOut =
                SushiRouter(SUSHIROUTER).swapExactTokensForTokens(amount0, 0, route, address(this), MAX_UINT);

            require(tokensOut[1] - repay > 0); // ensure profit is there

            ERC20(token1).transfer(msg.sender, repay);
        }
    }
}
