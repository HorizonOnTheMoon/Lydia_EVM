// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MockPyth is IPyth {
    mapping(bytes32 => PythStructs.Price) private prices;

    function setPrice(bytes32 id, int64 price, uint64 publishTime) external {
        prices[id] = PythStructs.Price({
            price: price,
            conf: uint64(price > 0 ? uint64(price) / 100 : 0),
            expo: -8,
            publishTime: publishTime
        });
    }

    function getPrice(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getPriceNoOlderThan(bytes32 id, uint age) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPrice(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function updatePriceFeeds(bytes[] calldata updateData) external payable override {
        // Mock implementation - does nothing
    }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable override {
        // Mock implementation - does nothing
    }

    function getUpdateFee(bytes[] calldata updateData) external pure override returns (uint feeAmount) {
        return updateData.length * 1; // 1 wei per update
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable override returns (PythStructs.PriceFeed[] memory priceFeeds) {
        // Mock implementation
        priceFeeds = new PythStructs.PriceFeed[](priceIds.length);
        for (uint i = 0; i < priceIds.length; i++) {
            priceFeeds[i].id = priceIds[i];
            priceFeeds[i].price = prices[priceIds[i]];
            priceFeeds[i].emaPrice = prices[priceIds[i]];
        }
    }

    function getValidTimePeriod() external pure override returns (uint validTimePeriod) {
        return 60; // 60 seconds
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable override returns (PythStructs.PriceFeed[] memory priceFeeds) {
        // Mock implementation
        priceFeeds = new PythStructs.PriceFeed[](priceIds.length);
        for (uint i = 0; i < priceIds.length; i++) {
            priceFeeds[i].id = priceIds[i];
            priceFeeds[i].price = prices[priceIds[i]];
            priceFeeds[i].emaPrice = prices[priceIds[i]];
        }
    }
}