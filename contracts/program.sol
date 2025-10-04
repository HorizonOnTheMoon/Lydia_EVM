// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract LydiaSpotToken is ERC20, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    IPyth public pythContract;
    IERC20 public usdcToken;

    address public adminWallet;
    bytes32 public tokenPriceFeedId;

    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public constant TOKEN_DECIMALS = 18;
    uint256 public constant USDC_DECIMALS = 6;

    mapping(bytes32 => bool) public usedNonces;

    event TokensPurchased(
        address indexed buyer,
        uint256 usdcAmount,
        uint256 tokenAmount,
        uint256 price,
        bytes32 nonce
    );

    event TokensSold(
        address indexed seller,
        uint256 tokenAmount,
        uint256 usdcAmount,
        uint256 price,
        bytes32 nonce
    );

    event AdminWalletUpdated(address indexed oldAdmin, address indexed newAdmin);
    event PriceFeedUpdated(bytes32 indexed oldFeedId, bytes32 indexed newFeedId);

    constructor(
        string memory _name,
        string memory _symbol,
        address _pythContract,
        address _usdcToken,
        address _adminWallet,
        bytes32 _tokenPriceFeedId
    ) ERC20(_name, _symbol) {
        pythContract = IPyth(_pythContract);
        usdcToken = IERC20(_usdcToken);
        adminWallet = _adminWallet;
        tokenPriceFeedId = _tokenPriceFeedId;
    }

    modifier validSignature(
        bytes32 nonce,
        uint256 amount,
        uint256 price,
        bytes memory signature
    ) {
        require(!usedNonces[nonce], "Nonce already used");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(msg.sender, nonce, amount, price))
            )
        );

        address recoveredSigner = messageHash.recover(signature);
        require(recoveredSigner == adminWallet, "Invalid admin signature");

        usedNonces[nonce] = true;
        _;
    }

    function buyTokens(
        uint256 usdcAmount,
        uint256 tokenPrice,
        bytes32 nonce,
        bytes memory adminSignature,
        bytes[] calldata priceUpdateData
    ) external payable nonReentrant validSignature(nonce, usdcAmount, tokenPrice, adminSignature) {
        require(usdcAmount > 0, "USDC amount must be positive");
        require(tokenPrice > 0, "Token price must be positive");

        uint256 fee = pythContract.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee for price update");

        pythContract.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory pythPrice = pythContract.getPrice(tokenPriceFeedId);
        require(pythPrice.price > 0, "Invalid price from oracle");

        uint256 oraclePrice = uint256(uint64(pythPrice.price));
        uint256 priceDiff = tokenPrice > oraclePrice ?
            tokenPrice - oraclePrice : oraclePrice - tokenPrice;

        require(
            priceDiff <= (oraclePrice * 5) / 100,
            "Price deviation too high (>5%)"
        );

        require(
            usdcToken.transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        uint256 tokenAmount = (usdcAmount * (10 ** TOKEN_DECIMALS) * PRICE_PRECISION) /
                             (tokenPrice * (10 ** USDC_DECIMALS));

        _mint(msg.sender, tokenAmount);

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }

        emit TokensPurchased(msg.sender, usdcAmount, tokenAmount, tokenPrice, nonce);
    }

    function sellTokens(
        uint256 tokenAmount,
        uint256 tokenPrice,
        bytes32 nonce,
        bytes memory adminSignature,
        bytes[] calldata priceUpdateData
    ) external payable nonReentrant validSignature(nonce, tokenAmount, tokenPrice, adminSignature) {
        require(tokenAmount > 0, "Token amount must be positive");
        require(tokenPrice > 0, "Token price must be positive");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 fee = pythContract.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee for price update");

        pythContract.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory pythPrice = pythContract.getPrice(tokenPriceFeedId);
        require(pythPrice.price > 0, "Invalid price from oracle");

        uint256 oraclePrice = uint256(uint64(pythPrice.price));
        uint256 priceDiff = tokenPrice > oraclePrice ?
            tokenPrice - oraclePrice : oraclePrice - tokenPrice;

        require(
            priceDiff <= (oraclePrice * 5) / 100,
            "Price deviation too high (>5%)"
        );

        uint256 usdcAmount = (tokenAmount * tokenPrice * (10 ** USDC_DECIMALS)) /
                           ((10 ** TOKEN_DECIMALS) * PRICE_PRECISION);

        require(
            usdcToken.balanceOf(address(this)) >= usdcAmount,
            "Insufficient USDC in contract"
        );

        _burn(msg.sender, tokenAmount);

        require(
            usdcToken.transfer(msg.sender, usdcAmount),
            "USDC transfer failed"
        );

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }

        emit TokensSold(msg.sender, tokenAmount, usdcAmount, tokenPrice, nonce);
    }

    function getCurrentPrice() external view returns (int64, uint256) {
        PythStructs.Price memory price = pythContract.getPrice(tokenPriceFeedId);
        return (price.price, uint256(price.publishTime));
    }

    function setAdminWallet(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Invalid admin address");
        address oldAdmin = adminWallet;
        adminWallet = _newAdmin;
        emit AdminWalletUpdated(oldAdmin, _newAdmin);
    }

    function setPriceFeed(bytes32 _newPriceFeedId) external onlyOwner {
        bytes32 oldFeedId = tokenPriceFeedId;
        tokenPriceFeedId = _newPriceFeedId;
        emit PriceFeedUpdated(oldFeedId, _newPriceFeedId);
    }

    function withdrawUSDC(uint256 amount) external onlyOwner {
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Insufficient USDC balance"
        );
        require(
            usdcToken.transfer(owner(), amount),
            "USDC transfer failed"
        );
    }

    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }

    function getContractUSDCBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    receive() external payable {}
}