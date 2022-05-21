# Zyfty Techinal Specification

Zyfty is a solution that provides property ownership in the form of long-term leasees as NFTs.

## NFT

Most NFTs hold only their value in their selling price and do not hold any
debt.  Many properties, however, have some liabilities associated with them
over the life of the property, and this is the purpose of having liens built
into the Zyfty NFTs.

### NFT Minting Fee

The Zyfty NFT will direct a minting fee of 0.5% of the proceeds of every sale to Zyfty.

### Reimbursement Account

The Zyfty Lease Agreement will call for the NFT Owner to put required recurring
fees into the NFT as those fees occur and are paid by Zyfty. These fees include
property taxes, Homeowners Association Fees and other fees specific to each
property.  The fees must be paid by the NFT Owner into the Reimbursement
Account per the schedule in the Lease Agreement.  The NFT Owner has complete
control of the Reimbursement Account.  Zyfty will draw down from the
Reimbursement Account at its discretion to pays fees on behalf of the NFT Owner
to collect reimbursement for the fees paid.  Any fees not placed into the
Reimbursement Account by the NFT Owner as required will accrue to the Primary
Lien and will bear interest as defined in the Lease Agreement.  

#### Liens

A property can hold a total of four liens (limited due to space concerns).
There are two types of liens. The first type of lien is the ”Primary Lien”.
The Primary Lien can never be removed and will be an amount equal to the fees
that were owed but not put into the Reimbursement Account by the NFT Owner as
required by the lease. If no fees are owed by the NFT Owner the Primary Lien
value will be zero. The other liens (second, third and fourth) are “Secondary
Liens” and are used if the NFT Owner allows additional liens to be placed on
the property to secure a loan or for some other agreement.

There are two subtypes of liens. They are:
- Dynamic Value: A lien that can have value added onto it.
- Parametric Value: A lien which has its value calculated by an interval, 
  total time, and a rate.

The primary lien is a parametric value lien.

#### Lien Creation

The Primary Lien is created by Zyfty with a value of zero when the NFT is
created.  If the NFT Owner does not make timely fee payments per the terms of
the Lease Agreement the Primary Lien is increased by Zyfty to equal the value
of the overdue fee payments plus accrued interest as defined in the Lease
Agreement.  These increases occur at Zyfty’s discretion or upon interaction
with a Sales Contract.  Secondary Liens are created by a third party that the
NFT Owner is entering into an agreement with (like a lender providing a loan
against an owners NFT).  The NFT Owner must allow a Secondary Lien to be
placed.  To place a Secondary Lien, the third party will make a call
to `proposeLien`, specifying a lien value and wallet address of the lien
provider, what type of asset the lien secures and if the lien is dynamic or
parametric.  The NFT Owner indicates that they are allowing the lien to be placed
by calling `confirmLien`, after which they will have no control over the lien.
The lien can only be removed by the lien holder when the agreement that the
lien secures has been fulfilled by the NFT Owner, or when the lien is paid by
the NFT Owner, or by default when the NFT is sold and all of the liens are paid
from the sale proceeds.

##### Paying Liens

The NFT Owner can pay off the Primary Lien by placing the full amount of the
Primary Lien in the Reimbursement Account.  After Zyfty draws down the value of
any payments made on the NFT Owner’s behalf plus any accrued interest, it will
set the lien value to zero.  The NFT Owner can pay off Secondary Liens by
sending the lien value to the lien holder, after which the lien holder will
remove the lien, or by paying the lien value to the NFT, which will send the
funds to the lien holder and remove the lien.

##### Increasing Liens

If a lien is dynamic cost, then the lien provider can increase the value of the
lien as defined by the agreement between the lien provider and the NFT Owner.

##### Destroying an NFT

Under specific circumstances when the NFT Owner has breached the terms of the
Lease Agreement, or when the NFT Owner wishes to return its NFT to Zyfty and
take traditional ownership of the property per the terms of the Lease
Agreement, or if the NFT has been lost and the NFT Owner had registered their
personal information with Zyfty and requests replacement, Zyfty will reclaim
and destroy the NFT.

### NFT functions

```
mint(address recipient, string memory meta_data_uri, address lienProvider, address lienAssetType) returns(uint256)
increaseReserve(uint256 tokenID)
redeemReserve(uint256 tokenID, uint256 value) 
getLien(uint256 tokenID, uint8 lienID)
addLien(uint256 tokenID, uint256 value, address lienProvider, bool dynamicCost, address assetType) returns(uint8)
payLien(uint256 tokenID, uint8 lienID, address assetType, uint256 amount) returns(uint256)
increaseLien(uint256 tokenID, uint8 lienID, uint256 amount) 
```


## Sales Contract

The Sales Contract works as a basic, time-locked type contract.  Over time
there will be an approved list of valid sales contracts controlled by the NFT
creator (Zyfty).  The only way the NFT can be transferred is through an
approved Sales Contract.

### Selling a Property

The NFT Owner or the marketplace selling the NFT places the NFT and the
seller’s terms of sale “into” the Sales Contract (via sellProperty).  The terms
of sale include the sales price, the non-refundable deposit amount (if any),
the refundable deposit amount (if any), the buyer’s requirement to agree to all
the terms of the Lease Agreement and the time allotted for closing. The NFT
sales price must be enough to pay the 0.5% NFT Minting Fee to Zyfty, to clear
all lien amounts and to pay the gas fee for the transaction, or the property
cannot be sold.

### Buying

The NFT buyer or the marketplace selling the NFT places the buyer’s deposit and
the buyer’s terms of sale “into” the Sales Contract (via buyProperty).  The
terms of sale will include any required property walk-thrus, inspections,
repairs, etc.

### Executing

As soon as all of the terms of sale are met, the Sales Contract can be executed
by the buyer or the seller.  Upon execution the Sales Contract pulls the full
amount of the sales price, less any deposits already posted, from the buyer and
uses those funds to pay the 0.5% NFT Transfer Fee to Zyfty, to pay all lien
amounts, to pay the gas fees and to pay the remaining proceeds of the sale to
the NFT Owner.  It then moves the NFT to the buyer.  If the buyer does not have
the required funds available to pay the sales price less any prior deposits
when the sales contract executes, the Sales Contract fails.  If all terms of
sale are not met prior to the time allotted for closing, the Sale Contract is
terminated. Upon termination the NFT is returned to the NFT Owner and any
refundable deposits are returned to the buyer. 

### Sales Contract function
```
listProperty(address nftContract, uint256 tokenId, address asset, uint256 price, uint256 time) returns(uint256)
listPropertyBuyer(address nftContract, uint256 tokenId, address asset, uint256 price, uint256 time, address buyer) returns(uint256)
buyProperty(uint256 listingId) 
execute(uint256 listingId)
revertBuyer(uint256 listingId)
revertSeller(uint256 listingId)
```
