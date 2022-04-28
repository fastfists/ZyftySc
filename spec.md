# Zyfty Techinal Specification

Zyfty is a solution that transforms properties into NFTs

## NFT

Most NFTs hold all their value in their selling price, and don't hold debt,
however, properties also have some form of liabilities surrounding them, this
is the purpose of having leans.

### Leans

A property can hold a total of 3 leans (limited due to space concerns) 2 types of leans.

The first lean is the `primary lean` and can never be removed.
The second and third leans are used when if the owner needs to take additional
leans out on the property

The two types of leans are:
- Dynamic Cost: The lean is able to have value added onto it. 
- Static Cost:  A lean that is constant and cannot be changed after creation

The primary lean is always set to static cost.

#### Lean Creation

The primary lean is created on initialization and the secondary and tertiary
leans are created by the owner making a call to `addLean` specifying a value
an address of who the lean provider is (i.e where the money will be sent to)
how much the lean is for, what type of asset the lean will be paid for as well
as if the lean is able dynamic or static.

##### Paying Leans

The owner can pay leans off by sending the amount by sending funds in terms of
ERC20 tokens to the smart contract of whatever asset type the lean specified.

##### Increasing Leans
If the lean is dynamic cost, then the lean provider can increase the value of the lean.

### Reserve

The reserve account is used to hold any value that the property itself holds.

### NFT functions

```
mint(address recipient, string memory meta_data_uri, address leanProvider, address leanAssetType) returns(uint256)
increaseReserve(uint256 tokenID)
redeemReserve(uint256 tokenID, uint256 value) 
getLean(uint256 tokenID, uint8 leanID)
addLean(uint256 tokenID, uint256 value, address leanProvider, bool dynamicCost, address assetType) returns(uint8)
payLean(uint256 tokenID, uint8 leanID, address assetType, uint256 amount) returns(uint256)
increaseLean(uint256 tokenID, uint8 leanID, uint256 amount) 
```

## Escrow Contract

### Listing a property for sell

The escrow contract works as a basic timelocked escrow contract. A NFT holder
first calls `listProperty` specifying the contract information, asset which it
wants to receive payment in and a time in seconds for how long the contract
will hold the asset. When this is received, the primary lean must be fully paid
out for it to hold the asset. The user can optically specify a buyer that will
only allow a specific address to buy the NFT asset. This function returns a
listing address

### Buying

A person who wants to buy an NFT will call `buyProperty` specifying the
listingId that they wish to buy. If the person signing the contract is a
verified buyer (or if a buyer was not assigned) the contract pulls the asset
specified in the listing and locks the value of the token. This function must
be signed within the time window that the seller specified.

### Executing

When both parties agree to the arrangement, either the seller or the buyer
must call `execute` after the time window ends. This is so the users can 
choose who will pay the gas fee for the transaction.

### Reverting

If any issues occurred the buyer or seller cal call `revertBuyer` or `revertSeller`
respectively sending the NFT or ERC20 token back to the original holder.

### Escrow functions

```
listProperty(address nftContract, uint256 tokenId, address asset, uint256 price, uint256 time) returns(uint256)
listPropertyBuyer(address nftContract, uint256 tokenId, address asset, uint256 price, uint256 time, address buyer) returns(uint256)
buyProperty(uint256 listingId) 
execute(uint256 listingId)
revertBuyer(uint256 listingId)
revertSeller(uint256 listingId)
```
