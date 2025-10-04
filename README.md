# Lydia Spot Token Contract

Bu proje, Pyth Network oracle entegrasyonu ile spot token alım/satımı için geliştirilmiş bir Ethereum smart contract'ıdır.

## Özellikler

- ✅ USDC ile token alım/satımı
- ✅ Pyth Network fiyat oracle entegrasyonu
- ✅ Admin imzası ile işlem doğrulama
- ✅ Token mint/burn mekanizması
- ✅ %5 fiyat sapma koruması
- ✅ Reentrancy koruması
- ✅ Ownable ve güvenlik kontrolleri

## Kurulum

```bash
# Bağımlılıkları yükle
npm install

# Kontratları compile et
npm run compile

# Testleri çalıştır
npm run test

# Deploy et
npm run deploy:testnet
```

## Konfigürasyon

1. `.env` dosyasını oluştur:
```bash
cp .env.example .env
```

2. Gerekli değerleri doldur:
- `PRIVATE_KEY`: Deploy için private key
- `ADMIN_WALLET`: İmza kontrolü için admin cüzdan adresi
- `TOKEN_PRICE_FEED_ID`: Pyth Network price feed ID

## Contract Adresleri

### Pyth Network Contract Adresleri:
- **Ethereum**: `0x4305FB66699C3B2702D4d05CF36551390A4c69C6`
- **Arbitrum**: `0xff1a0f4744e8582DF1aE09D5611b887B6a12925C`
- **Polygon**: `0xff1a0f4744e8582DF1aE09D5611b887B6a12925C`
- **BSC**: `0x4D7E825f80bDf85e913E0DD2A2D54927e9dE1594`

### USDC Contract Adresleri:
- **Ethereum**: `0xA0b86a33E6441c1e6D8b86c3ff1C6E9cfFfDc8b4`
- **Arbitrum**: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
- **Polygon**: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`
- **BSC**: `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d`

## Kullanım

### Token Alımı (Buy)

```solidity
function buyTokens(
    uint256 usdcAmount,      // USDC miktarı (6 decimal)
    uint256 tokenPrice,      // Token fiyatı (8 decimal)
    bytes32 nonce,           // Tek kullanımlık nonce
    bytes memory adminSignature, // Admin imzası
    bytes[] calldata priceUpdateData // Pyth price update data
) external payable
```

### Token Satımı (Sell)

```solidity
function sellTokens(
    uint256 tokenAmount,     // Token miktarı (18 decimal)
    uint256 tokenPrice,      // Token fiyatı (8 decimal)
    bytes32 nonce,           // Tek kullanımlık nonce
    bytes memory adminSignature, // Admin imzası
    bytes[] calldata priceUpdateData // Pyth price update data
) external payable
```

## İmza Oluşturma

Admin imzası oluşturmak için:

```javascript
const messageHash = ethers.utils.keccak256(
    ethers.utils.solidityPack(
        ["address", "bytes32", "uint256", "uint256"],
        [userAddress, nonce, amount, price]
    )
);

const signature = await adminWallet.signMessage(
    ethers.utils.arrayify(messageHash)
);
```

## Güvenlik

- Tüm işlemler admin imzası gerektirir
- Nonce sistemi ile replay attack korunması
- Pyth oracle ile fiyat doğrulaması
- %5 fiyat sapma limiti
- Reentrancy guard
- Access control (Ownable)

## Test

```bash
npm run test
npm run coverage
```

## Deploy

```bash
# Local testnet
npm run node
npm run deploy:localhost

# Testnet
npm run deploy:testnet

# Mainnet
npm run deploy:mainnet
```

## Lisans

GPL-3.0