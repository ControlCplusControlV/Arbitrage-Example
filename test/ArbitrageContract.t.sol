// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../src/interfaces/ISushi.sol";
import "../src/interfaces/IERC20.sol";
import "../src/ArbitrageContract.sol";
import "./util/ERC20.sol";

contract ArbitrageContractTest {
    ArbitrageContract arb_contract;
    FakeERC20 tokenA;
    FakeERC20 tokenB;

    uint256 constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    SushiFactory sushi_factory;
    SushiPair sushi_pair;
    SushiRouter sushi_router;

    SushiFactory uni_factory;
    SushiPair uni_pair;
    SushiRouter uni_router;

    function setUp() public {
        // Deploy contracts
        tokenA = new FakeERC20("tokenA", "A", 18);
        tokenB = new FakeERC20("tokenB", "B", 18);

        (tokenA, tokenB) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);

        // Using Sushi Router and Factory
        arb_contract =
            new ArbitrageContract(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

        // Set up Sushi Pair
        sushi_factory = SushiFactory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
        sushi_router = SushiRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        sushi_pair = SushiPair(sushi_factory.createPair(address(tokenA), address(tokenB)));
        tokenA._mint(address(this), 50 ether);
        tokenB._mint(address(this), 100 ether);

        tokenA.approve(address(sushi_router), MAX_UINT);
        tokenB.approve(address(sushi_router), MAX_UINT);
        sushi_router.addLiquidity(address(tokenA), address(tokenB), 50 ether, 100 ether, 0, 0, address(this), MAX_UINT);

        // Set up Uni Pair
        uni_factory = SushiFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        uni_router = SushiRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uni_pair = SushiPair(uni_factory.createPair(address(tokenA), address(tokenB)));
        tokenA._mint(address(this), 100 ether);
        tokenB._mint(address(this), 50 ether);

        tokenA.approve(address(uni_router), MAX_UINT);
        tokenB.approve(address(uni_router), MAX_UINT);
        uni_router.addLiquidity(address(tokenA), address(tokenB), 100 ether, 50 ether, 0, 0, address(this), MAX_UINT);
    }

    function testArbitrage() public {
        uint256 start = tokenB.balanceOf(address(arb_contract));
        arb_contract.arbitrageMarket{value: 1}(address(uni_pair), 25 ether);
        uint256 end = tokenB.balanceOf(address(arb_contract));
        require(start < end, "No profit made");
    }
}
