pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RealestateNFT.sol";

contract RealestateEscrow is Ownable {
    // TODO will there be a unique escrow contract for each person, or just a single escrow contract
    RealestateNFT nft;

    enum PropertyState {NORMAL, DELETED}

    struct Account {
        address payable owner;
        uint256 thresholdLean;
        uint256 reserve;
        uint256 lean1;
        uint256 lean2;

        uint256 price;
        bool listed;
        PropertyState state;
    }

    mapping(uint256 => Account) accounts;

    event E_PropertyMade(uint256 tokenID);
    event E_PropertyListed(uint256 tokenID);
    event E_PropertySold(uint256 indexed tokenID, address from, address to);
    event E_PropertyTaken(uint256 indexed tokenID);

    constructor() {
        nft = new RealestateNFT("ZyftyNFT", "ZNFT");
    }

    // Owner of contract creates a new property
    // and the contract holds onto the NFT
    function newProperty(string memory meta_data_uri, uint256 threshold)
        public
        onlyOwner
        returns(uint256)
        {
        uint256 id = nft.mint(address(this), meta_data_uri);
        accounts[id]  = Account({thresholdLean : threshold,
                                lean1: 0,
                                lean2: 0,
                                reserve: 0,
                                listed: false,
                                price: 0,
                                state: PropertyState.NORMAL,
                                owner: payable(msg.sender)});

        emit E_PropertyMade(id);
        return id;
    }

    function listProperty(uint256 id, uint256 price)
        public
        {
        accounts[id].price = price;
        accounts[id].listed = true;

        emit E_PropertyListed(id);
    }

    function buyProperty(uint256 id) 
        public
        payable
        {
        require(accounts[id].listed);
        require(msg.value >= accounts[id].price);
        _zeroBalances(id); // TODO might not be a good idea to keep this around
        require(accounts[id].lean1 > 0, "Balances in lean1 must be fully paid out");

        accounts[id].listed = false;
        address oldOwner = accounts[id].owner;
        // Send profits from sale to the owner
        oldOwner.transfer(accounts[id].price);

        nft.transferFrom(address(this), msg.sender, id);

        accounts[id].owner = msg.sender;
        emit E_PropertySold(id, oldOwner, msg.sener);
    }

    function _zeroBalances(uint256 tokenId) internal {
        Account memory a = accounts[tokenId];
        if (a.lean1 > 0) {
            uint256 diff = a.reserve - a.lean1;
            if (diff >= 0) {
                a.reserve -= diff;
                a.lean1 = 0;
            } else {
                a.reserve = 0;
                a.lean1 -= a.reserve;
            }
        }
    }

    // Changes lean1 by adding or subtract delta, requires owners signature
    function changeLean(uint256 tokenId, uint256 delta)
        public
        onlyOwner
        returns(uint256)
        {
        accounts[tokenId].lean1 += delta;
        if (accounts[tokenId].lean1 > accounts[tokenId].thresholdLean) {
            // Delete the NFT
            accounts[tokenId].state = PropertyState.DELETED;
            revert("NFT deleted");
        }
        return accounts[tokenId].lean1;
    }

    // Changes reserve by adding or subtracting delta, requires either the owner
    // of the token, or the owner of the escrow contract
    function changeReserve(uint256 tokenId, uint256 delta)
        public
        ownerOrHolder(tokenId)
        returns(uint256)
        {
        accounts[tokenId].reserve += delta;

        return accounts[tokenId].reserve;
    }

    modifier ownerOrHolder(uint256 tokenId) {
        require(nft.ownerOf(tokenId) == msg.sender || owner() == msg.sender, "You must be the holder or the distributor");
        _;
    }

    modifier holderOnly(uint256 tokenId) {
        require(nft.ownerOf(tokenId) == msg.sender, "You must be the holder of the NFT");
        _;
    }
    
}
