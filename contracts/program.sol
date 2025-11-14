// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    uint256 public constant WITHDRAWAL_DELAY = 24 hours;

    mapping(bytes32 => bool) public usedNonces;

    struct PendingWithdrawal {
        address token;
        uint256 amount;
        uint256 unlockTime;
        bool exists;
    }

    mapping(bytes32 => PendingWithdrawal) public pendingWithdrawals;

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
    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed token, uint256 amount, uint256 unlockTime);
    event WithdrawalExecuted(bytes32 indexed withdrawalId, address indexed token, uint256 amount);
    event WithdrawalCancelled(bytes32 indexed withdrawalId);

    constructor(
        string memory _name,
        string memory _symbol,
        address _pythContract,
        address _usdcToken,
        address _adminWallet,
        bytes32 _tokenPriceFeedId
    ) ERC20(_name, _symbol) {
        require(_pythContract != address(0), "Invalid Pyth contract address");
        require(_usdcToken != address(0), "Invalid USDC token address");
        require(_adminWallet != address(0), "Invalid admin wallet address");
        require(_tokenPriceFeedId != bytes32(0), "Invalid price feed ID");

        pythContract = IPyth(_pythContract);
        usdcToken = IERC20(_usdcToken);
        adminWallet = _adminWallet;
        tokenPriceFeedId = _tokenPriceFeedId;
    }

    modifier validSignature(
        bytes32 functionSelector,
        bytes32 nonce,
        uint256 amount,
        uint256 price,
        bytes memory signature
    ) {
        require(!usedNonces[nonce], "Nonce already used");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(functionSelector, msg.sender, nonce, amount, price))
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
    ) external payable nonReentrant validSignature(keccak256("buyTokens"), nonce, usdcAmount, tokenPrice, adminSignature) {
        require(usdcAmount > 0, "USDC amount must be positive");
        require(tokenPrice > 0, "Token price must be positive");

        uint256 fee = pythContract.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee for price update");

        pythContract.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory pythPrice = pythContract.getPrice(tokenPriceFeedId);
        require(pythPrice.price > 0, "Invalid price from oracle");

        uint256 scaledTokenPrice;
        uint256 scaledOraclePrice;

        if (pythPrice.expo >= 0) {
            scaledOraclePrice = uint256(uint64(pythPrice.price)) * (10 ** uint32(pythPrice.expo)) * PRICE_PRECISION;
            scaledTokenPrice = tokenPrice;
        } else {
            uint32 absExpo = uint32(-pythPrice.expo);
            scaledOraclePrice = uint256(uint64(pythPrice.price)) * PRICE_PRECISION;
            scaledTokenPrice = tokenPrice * (10 ** absExpo);
        }

        uint256 priceDiff = scaledTokenPrice > scaledOraclePrice ?
            scaledTokenPrice - scaledOraclePrice : scaledOraclePrice - scaledTokenPrice;

        if (priceDiff * 1000 > scaledOraclePrice) {
            revert(string(abi.encodePacked(
                "Price deviation >0.1%: Diff=",
                Strings.toString(priceDiff * 100 / scaledOraclePrice),
                "%"
            )));
        }

        uint256 oraclePrice8Decimals;
        if (pythPrice.expo >= 0) {
            oraclePrice8Decimals = uint256(uint64(pythPrice.price)) * (10 ** uint32(pythPrice.expo)) * PRICE_PRECISION;
        } else {
            uint32 absExpo = uint32(-pythPrice.expo);
            oraclePrice8Decimals = (uint256(uint64(pythPrice.price)) * PRICE_PRECISION) / (10 ** absExpo);
        }

        require(
            usdcToken.transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        uint256 tokenAmount = (usdcAmount * (10 ** TOKEN_DECIMALS) * PRICE_PRECISION) /
                             (oraclePrice8Decimals * (10 ** USDC_DECIMALS));

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
    ) external payable nonReentrant validSignature(keccak256("sellTokens"), nonce, tokenAmount, tokenPrice, adminSignature) {
        require(tokenAmount > 0, "Token amount must be positive");
        require(tokenPrice > 0, "Token price must be positive");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 fee = pythContract.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee for price update");

        pythContract.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory pythPrice = pythContract.getPrice(tokenPriceFeedId);
        require(pythPrice.price > 0, "Invalid price from oracle");

        uint256 scaledTokenPrice;
        uint256 scaledOraclePrice;

        if (pythPrice.expo >= 0) {
            scaledOraclePrice = uint256(uint64(pythPrice.price)) * (10 ** uint32(pythPrice.expo)) * PRICE_PRECISION;
            scaledTokenPrice = tokenPrice;
        } else {
            uint32 absExpo = uint32(-pythPrice.expo);
            scaledOraclePrice = uint256(uint64(pythPrice.price)) * PRICE_PRECISION;
            scaledTokenPrice = tokenPrice * (10 ** absExpo);
        }

        uint256 priceDiff = scaledTokenPrice > scaledOraclePrice ?
            scaledTokenPrice - scaledOraclePrice : scaledOraclePrice - scaledTokenPrice;

        if (priceDiff * 1000 > scaledOraclePrice) {
            revert(string(abi.encodePacked(
                "Price deviation >0.1%: Diff=",
                Strings.toString(priceDiff * 100 / scaledOraclePrice),
                "%"
            )));
        }

        uint256 oraclePrice8Decimals;
        if (pythPrice.expo >= 0) {
            oraclePrice8Decimals = uint256(uint64(pythPrice.price)) * (10 ** uint32(pythPrice.expo)) * PRICE_PRECISION;
        } else {
            uint32 absExpo = uint32(-pythPrice.expo);
            oraclePrice8Decimals = (uint256(uint64(pythPrice.price)) * PRICE_PRECISION) / (10 ** absExpo);
        }

        uint256 usdcAmount = (tokenAmount * oraclePrice8Decimals * (10 ** USDC_DECIMALS)) /
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

    function requestWithdrawal(address token, uint256 amount) external onlyOwner returns (bytes32) {
        require(amount > 0, "Amount must be positive");

        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
        } else {
            require(
                usdcToken.balanceOf(address(this)) >= amount,
                "Insufficient token balance"
            );
        }

        bytes32 withdrawalId = keccak256(abi.encodePacked(token, amount, block.timestamp, owner()));
        uint256 unlockTime = block.timestamp + WITHDRAWAL_DELAY;

        pendingWithdrawals[withdrawalId] = PendingWithdrawal({
            token: token,
            amount: amount,
            unlockTime: unlockTime,
            exists: true
        });

        emit WithdrawalRequested(withdrawalId, token, amount, unlockTime);
        return withdrawalId;
    }

    function executeWithdrawal(bytes32 withdrawalId) external onlyOwner {
        PendingWithdrawal memory withdrawal = pendingWithdrawals[withdrawalId];

        require(withdrawal.exists, "Withdrawal does not exist");
        require(block.timestamp >= withdrawal.unlockTime, "Timelock has not expired");

        delete pendingWithdrawals[withdrawalId];

        if (withdrawal.token == address(0)) {
            require(address(this).balance >= withdrawal.amount, "Insufficient ETH balance");
            payable(owner()).transfer(withdrawal.amount);
        } else {
            require(
                usdcToken.balanceOf(address(this)) >= withdrawal.amount,
                "Insufficient token balance"
            );
            require(
                usdcToken.transfer(owner(), withdrawal.amount),
                "Token transfer failed"
            );
        }

        emit WithdrawalExecuted(withdrawalId, withdrawal.token, withdrawal.amount);
    }

    function cancelWithdrawal(bytes32 withdrawalId) external onlyOwner {
        require(pendingWithdrawals[withdrawalId].exists, "Withdrawal does not exist");

        delete pendingWithdrawals[withdrawalId];
        emit WithdrawalCancelled(withdrawalId);
    }

    function getContractUSDCBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    receive() external payable {}
}