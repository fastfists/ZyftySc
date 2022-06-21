pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


import "contracts/ZyftyNFT.sol";

contract TestToken is ERC20 {
    constructor(address a, address b, address c, uint256 amount) ERC20("TestToken", "TT"){
        _mint(a, amount);
        _mint(b, amount);
        _mint(c, amount);
    }
}

contract ZyftySalesContract is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _propertyIds;

    enum EscrowState {
        NOT_CREATED, // Have initial state be not created for after clearing
        INITIALIZED,
        FUNDED,
        CANCELED
    }

    event E_PropertyListed(uint256 propertyId);
    event E_PropertySold(uint256 indexed propertyId, address from, address to);

    struct ListedProperty {
        address nftContract;
        uint256 tokenID;
        address seller;
        address buyer;
        uint256 time; // seconds
        address asset; // do both
        uint256 price;
        uint256 created;

        bool buyerPaid;
        EscrowState state;
    }

    //      listingID   Property
    mapping (uint256 => ListedProperty) propertyListing;
    address private admin;

    constructor(address zyftyAdmin) {
        admin = zyftyAdmin;
    }

    function sellPropertyBuyer(
            address nftContract,
            uint256 tokenId,
            uint256 price,
            uint256 time,
            address buyer)
        public
        returns(uint256)
        {
        require(nftContract != address(0), "NFT Contract is zero address");
        ZyftyNFT nft = ZyftyNFT(nftContract);
        nft.transferFrom(msg.sender, address(this), tokenId);
        try nft.updateLien(tokenId) {
        } catch {}
        _propertyIds.increment();
        uint256 id =_propertyIds.current();
        propertyListing[id] = ListedProperty({nftContract: nftContract,
                                              tokenID: tokenId,
                                              time: time,
                                              asset: nft.asset(tokenId),
                                              price: price,
                                              buyer: buyer,
                                              seller: msg.sender,
                                              buyerPaid: false,
                                              created: block.timestamp,
                                              state: EscrowState.INITIALIZED});
        emit E_PropertyListed(id);
        return id;
    }

    function sellProperty(
            address nftContract,
            uint256 tokenId,
            uint256 price,
            uint256 time)
            public {
        sellPropertyBuyer(nftContract, tokenId, price, time, address(0));
    }

    function buyProperty(uint256 id) 
        public
        inState(id, EscrowState.INITIALIZED)
        withinWindow(id)
        {
        require(propertyListing[id].buyer == address(0)
            || msg.sender == propertyListing[id].buyer,
            "You are not authorized to buy this");
        IERC20 token = IERC20(propertyListing[id].asset);

        token.transferFrom(msg.sender, address(this), propertyListing[id].price);
        propertyListing[id].state = EscrowState.FUNDED;
        propertyListing[id].buyerPaid = true;
        propertyListing[id].buyer = msg.sender;
    }

    function revertSeller(uint256 id)
        public
        afterWindow(id)
        {
        require(msg.sender == propertyListing[id].seller, "You must be the seller");
        IERC721 nft = IERC721(propertyListing[id].nftContract);
        nft.transferFrom(address(this), msg.sender, id);
        propertyListing[id].state = EscrowState.CANCELED;
        if (propertyListing[id].buyerPaid == false) {
            cleanup(id);
        }
    }

    function revertBuyer(uint256 id)
        public
        afterWindow(id)
        {
        require(propertyListing[id].buyerPaid == true, "Buyer never paid");
        require(msg.sender == propertyListing[id].buyer, "You must be the buyer");
        IERC20 token = IERC20(propertyListing[id].asset);
        token.transfer(propertyListing[id].buyer, propertyListing[id].price);
        if (propertyListing[id].state == EscrowState.CANCELED) {
            cleanup(id);
        } else {
            propertyListing[id].state = EscrowState.CANCELED;
            propertyListing[id].buyerPaid = false;
        }
    }

    function execute(uint256 id)
        public
        withinWindow(id)
        inState(id, EscrowState.FUNDED)
        {
        address buyer =  propertyListing[id].buyer;
        address seller = propertyListing[id].seller;
        require(msg.sender == buyer || msg.sender == seller);
        ZyftyNFT nft = ZyftyNFT(propertyListing[id].nftContract);
        IERC20 token = IERC20(propertyListing[id].asset);

        uint256 fees = propertyListing[id].price/200;
        require(propertyListing[id].price - (nft.updateLien(propertyListing[id].tokenID) + fees) >= 0, "Not enough funds to fully payout, must revert");
        // Approve the transfer to increase the reserve account
        token.approve(propertyListing[id].nftContract, propertyListing[id].price - fees);
        nft.increaseReserve(propertyListing[id].tokenID, propertyListing[id].price - fees);

        nft.balanceAccounts(propertyListing[id].tokenID);

        uint256 remainingFunds = nft.getReserve(propertyListing[id].tokenID);
        nft.redeemReserve(propertyListing[id].tokenID, remainingFunds);

        // Should already hold these fees
        token.transfer(admin, fees);
        // Proceeds after liens paid go here
        token.transfer(seller, remainingFunds);

        // Finally transfer the NFT to the buyer
        nft.transferFrom(address(this), buyer, propertyListing[id].tokenID);
        emit E_PropertySold(id, seller, buyer);
        // cleanup
        cleanup(id);
    }

    function cleanup(uint256 id) internal {
        delete propertyListing[id];
    }

    modifier withinWindow(uint256 id) {
        require(propertyListing[id].created + propertyListing[id].time >= block.timestamp, "Window is closed");
        _;
    }

    modifier afterWindow(uint256 id) {
        require(block.timestamp >= propertyListing[id].created + propertyListing[id].time, "Window is still open");
        _;
    }

    modifier inState(uint256 id, EscrowState state) {
        require(propertyListing[id].state == state);
        _;
    }

    function getProperty(uint256 id) public view returns(ListedProperty memory) {
        return propertyListing[id];
    }

}
