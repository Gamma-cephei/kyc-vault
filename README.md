# KYC Vault - Self-Sovereign Identity Verification

A decentralized KYC (Know Your Customer) verification and storage system built on the Stacks blockchain using Clarity smart contracts. This system enables users to maintain control over their identity data while providing verifiable credentials for compliance and business purposes.

## 🌟 Features

### Self-Sovereign Identity
- **User-Controlled Data**: Users maintain full control over their identity information
- **Granular Permissions**: Fine-grained access control for data sharing
- **Privacy by Design**: Only document hashes stored on-chain, actual documents remain off-chain
- **Data Portability**: Users can delete their data at any time (GDPR compliant)

### Multi-Level Verification
- **Basic Level (1)**: Standard identity verification
- **Enhanced Level (2)**: Advanced verification with additional documentation
- **Institutional Level (3)**: Enterprise-grade verification for business entities

### Decentralized Verification Network
- **Authorized Verifiers**: Network of trusted entities that can verify identities
- **Reputation System**: Verifiers are authorized by contract governance
- **Time-Based Expiry**: KYC verifications have configurable expiration dates

## 🚀 Getting Started

### Prerequisites
- Stacks wallet (Hiro Wallet, Xverse, etc.)
- STX tokens for transaction fees and verification fees
- Access to Stacks blockchain (mainnet or testnet)

### Deployment

1. **Deploy the Contract**
   ```bash
   clarinet deploy --network testnet
   ```

2. **Initialize Verifiers**
   ```clarity
   (contract-call? .kyc-vault add-verifier 'SP1ABC...XYZ u2)
   ```

3. **Set Verification Fee** (Optional)
   ```clarity
   (contract-call? .kyc-vault set-verification-fee u2000000) ;; 2 STX
   ```

## 📖 Usage Guide

### For Users

#### 1. Submit KYC Request
```clarity
(contract-call? .kyc-vault submit-kyc-request 
  0x1234567890abcdef... ;; document hash
  u2 ;; verification level (1-3)
  "https://ipfs.io/ipfs/Qm..." ;; metadata URI
)
```

#### 2. Grant Access to Third Parties
```clarity
(contract-call? .kyc-vault grant-access 
  'SP1XYZ...ABC ;; accessor principal
  u1 ;; permission level
  u52560 ;; duration in blocks (~1 year)
)
```

#### 3. Set User Preferences
```clarity
(contract-call? .kyc-vault set-user-preferences 
  u1 ;; auto-approve level
  true ;; notifications enabled
  u365 ;; data retention period (days)
)
```

#### 4. Revoke Access
```clarity
(contract-call? .kyc-vault revoke-access 'SP1XYZ...ABC)
```

### For Verifiers

#### 1. Verify KYC Submission
```clarity
(contract-call? .kyc-vault verify-kyc 
  'SP1USER...ABC ;; user principal
  true ;; approved
  u525600 ;; expiry in blocks (~10 years)
)
```

#### 2. Update KYC Expiry
```clarity
(contract-call? .kyc-vault update-kyc-expiry 
  'SP1USER...ABC ;; user principal
  u1051200 ;; new expiry in blocks
)
```

### For Third Parties

#### 1. Check KYC Status
```clarity
(contract-call? .kyc-vault get-kyc-status 'SP1USER...ABC)
```

#### 2. Verify Access Permission
```clarity
(contract-call? .kyc-vault can-access-kyc 
  'SP1USER...ABC ;; user
  'SP1ACCESSOR...XYZ ;; accessor
  u2 ;; required level
)
```

## 🔐 Security Model

### Access Control
- **Contract Owner**: Can add/remove verifiers and withdraw fees
- **Authorized Verifiers**: Can verify KYC submissions up to their authorized level
- **Users**: Control their own data and access permissions
- **Third Parties**: Can only access data with explicit user permission

### Privacy Protection
- Document content never stored on-chain
- Only cryptographic hashes and metadata URIs stored
- Users can permanently delete their data
- Time-bound access permissions

### Anti-Spam Measures
- Verification fee required for KYC submissions
- One KYC record per user (prevents duplicate submissions)
- Authorized verifier network prevents fake verifications

## 📊 Data Structure

### KYC Record
```clarity
{
  kyc-id: uint,
  status: uint, ;; 0=pending, 1=verified, 2=rejected, 3=expired
  verification-level: uint, ;; 1=basic, 2=enhanced, 3=institutional
  verified-at: uint,
  expires-at: uint,
  document-hash: (buff 32),
  verifier: principal,
  metadata-uri: (string-ascii 256)
}
```

### Permission Record
```clarity
{
  granted: bool,
  permission-level: uint, ;; 1=basic, 2=detailed, 3=full
  granted-at: uint,
  expires-at: uint
}
```

## 🛠 API Reference

### Public Functions

#### User Functions
- `submit-kyc-request(document-hash, verification-level, metadata-uri)`
- `grant-access(accessor, permission-level, duration-blocks)`
- `revoke-access(accessor)`
- `set-user-preferences(auto-approve-level, notification-enabled, retention-period)`
- `delete-my-data()`

#### Verifier Functions
- `verify-kyc(user, approved, expiry-blocks)`
- `update-kyc-expiry(user, new-expiry)`

#### Admin Functions
- `add-verifier(verifier, level)`
- `remove-verifier(verifier)`
- `set-verification-fee(new-fee)`
- `withdraw-fees(amount)`

### Read-Only Functions

#### Query Functions
- `get-kyc-status(user)` - Get complete KYC record
- `is-kyc-valid(user)` - Check if KYC is currently valid
- `get-verification-level(user)` - Get user's verification level
- `get-access-permission(user, accessor)` - Check access permissions
- `can-access-kyc(user, accessor, required-level)` - Verify access rights
- `get-user-preferences(user)` - Get user preferences
- `get-verifier-info(verifier)` - Get verifier information

## 🔄 Integration Examples

### DeFi Protocol Integration
```clarity
;; Check if user has sufficient KYC level for high-value transactions
(define-private (can-execute-large-trade (user principal) (amount uint))
  (let ((required-level (if (> amount u1000000) u2 u1)))
    (match (contract-call? .kyc-vault get-verification-level user)
      level (>= level required-level)
      false)))
```

### Access Control for dApps
```clarity
;; Verify user has granted access to your application
(define-private (has-app-access (user principal))
  (contract-call? .kyc-vault can-access-kyc 
    user 
    (as-contract tx-sender) 
    u1))
```

## 🔧 Configuration

### Network Settings
- **Mainnet**: Deploy with production verifiers and higher fees
- **Testnet**: Use for development and testing with lower fees
- **Devnet**: Local development with mock verifiers

### Recommended Settings
- **Basic Verification Fee**: 1-2 STX
- **KYC Expiry**: 1-2 years (525,600-1,051,200 blocks)
- **Access Permission Duration**: 30-365 days
- **Auto-approval Level**: Level 1 for most users

## 🚨 Error Codes

- `u401` - Unauthorized access
- `u404` - Record not found
- `u409` - Record already exists
- `u400` - Invalid input parameters
- `u410` - KYC expired

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Install Clarinet
curl --proto '=https' --tlsv1.2 -sSf https://sh.clarinet.io | sh

# Clone and setup
git clone <repository-url>
cd kyc-vault
clarinet check
clarinet test
```
