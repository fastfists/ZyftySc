pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RealestateNFT.sol";

contract RealestateEscrow is Ownable {
    // TODO will there be a unique escrow contract for each person, or just a single escrow contract
    RealestateNFT public nft;

    enum PropertyState {NORMAL, PENDING_LEAN2_ACCEPT, DELETED}

    struct Account {
        address payable owner;
        uint256 thresholdLean;
        uint256 reserve;
        uint256 lean1;
        uint256 lean2;

        uint256 price;
        uint256 amountProposed;
        bool listed;
        PropertyState state;
    }

    mapping(uint256 => Account) accounts;

    event E_PropertyMade(uint256 tokenID);
    event E_PropertySold(uint256 indexed tokenID, address from, address to);
    event E_PropertyTaken(uint256 indexed tokenID);

    event E_Lean2TransferProposed(uint256 indexed tokenID, uint256 amount);
    event E_Lean2TransferAccepted(uint256 id, uint256 amount);
    event E_Lean2TransferDenied(uint256 id, uint256 amountToTransfer);
    event E_PropertyListed(uint256 tokenID);


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
                                amountProposed: 0,
                                owner: payable(msg.sender)});

        emit E_PropertyMade(id);
        return id;
    }

    // Transfers amountToTransfer from lean1 into lean2, requires
    // owner of contract to sign
    function proposeLean2Transfer(uint256 id, uint256 amountToTransfer) 
        public
        onlyHolder(id)
        {
        require(accounts[id].lean1 >= amountToTransfer, "Amount to transfer is too high");
        accounts[id].state = PropertyState.PENDING_LEAN2_ACCEPT;
        accounts[id].amountProposed = amountToTransfer;
        emit E_Lean2TransferProposed(id, accounts[id].amountProposed);
    }

    function acceptLean2Transfer(uint256 id, uint256 amount)
        public
        onlyOwner
        inState(id, PropertyState.PENDING_LEAN2_ACCEPT)
        {
        require(amount == accounts[id].amountProposed);
        accounts[id].lean2 = accounts[id].amountProposed;
        accounts[id].lean1 -= accounts[id].amountProposed;
        accounts[id].state = PropertyState.NORMAL;
        emit E_Lean2TransferAccepted(id, accounts[id].amountProposed);
    }

    function denyLean2Transfer(uint256 id) 
        public
        onlyOwner
        inState(id, PropertyState.PENDING_LEAN2_ACCEPT)
        {
        accounts[id].state = PropertyState.NORMAL;
        uint256 proposed = accounts[id].amountProposed;
        accounts[id].amountProposed = 0;
        emit E_Lean2TransferDenied(id, proposed);
    }

    // Decreases value in lean2
    // TODO does this value go from lean2 -> lean1 or does it just poof?
    // TODO This could potentially be dangerous...
    function decreaseLean2(uint256 id, uint256 amount)
        public
        onlyOwner
        returns(uint256)
        {
        require(amount > 0, "Must be a positive number");
        require(accounts[id].lean2 >= amount, "Amount is too high");
        accounts[id].lean2 -= amount;
        accounts[id].lean1 += amount;
        return accounts[id].lean2;
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
        require(accounts[id].listed, "This property is not listed");
        require(msg.value >= accounts[id].price, "Price is too low");
        _zeroBalances(id); // TODO might not be a good idea to keep this around
        require(accounts[id].lean1 == 0, "Balances in lean1 must be fully paid out");

        accounts[id].listed = false;
        address payable oldOwner = accounts[id].owner;
        // Send profits from sale to the owner
        oldOwner.transfer(accounts[id].price);

        nft.transferFrom(address(this), msg.sender, id);

        accounts[id].owner = payable(msg.sender);
        emit E_PropertySold(id, oldOwner, msg.sender);
    }

    function _zeroBalances(uint256 tokenId) internal {
        Account memory a = accounts[tokenId];
        if (a.lean1 > 0) {
            int256 diff = int256(a.reserve) - int256(a.lean1);
            if (diff >= 0) {
                a.reserve -= a.lean1;
                a.lean1 = 0;
            } else {
                a.reserve = 0;
                a.lean1 -= a.reserve;
            }
        }
        accounts[tokenId] = a;
    }

    // Changes lean1 by adding or subtract delta, requires owners signature
    function changeLean(uint256 tokenId, uint256 delta)
        public
        onlyOwner
        returns(uint256)
        {
        accounts[tokenId].lean1 += delta;
        if (accounts[tokenId].lean1 > accounts[tokenId].thresholdLean) {
            // For now only change lean before removing the NFT
            _zeroBalances(tokenId);
            if (accounts[tokenId].lean1 > accounts[tokenId].thresholdLean) {
                // Delete the NFT
                accounts[tokenId].state = PropertyState.DELETED;
                emit E_PropertyTaken(tokenId);
                // Delete the NFT
                nft.burn(tokenId);
            }
        }
        return accounts[tokenId].lean1;
    }

    // Changes reserve by adding, requires either the owner
    // of the token, or the owner of the escrow contract
    function changeReserve(uint256 tokenId, uint256 delta)
        public
        payable
        ownerOrHolder(tokenId)
        returns(uint256)
        {
        require(delta >= 0, "Must be positive increase only");
        require(msg.value == delta, "Value must be equal to delta");
        accounts[tokenId].reserve += delta;

        return accounts[tokenId].reserve;
    }

    function redeemReserve(uint256 id, uint256 delta)
        public
        onlyHolder(id)
        returns(uint256)
        {
        require(accounts[id].reserve >= delta, "Not enough money in account");
        payable(msg.sender).transfer(delta);

        accounts[id].reserve -= delta;
        return accounts[id].reserve;
    }

    function getBalance()
        public
        view
        returns(uint256)
        {
        return address(this).balance;
    }

    function getProperty(uint256 id)
        public
        view
        returns(Account memory)
        {
            return accounts[id];
    }

    modifier ownerOrHolder(uint256 tokenId) {
        require(accounts[tokenId].state != PropertyState.DELETED, "NFT is deleted");
        require(nft.ownerOf(tokenId) == msg.sender || owner() == msg.sender, "You must be the holder or the distributor");
        _;
    }

    modifier onlyHolder(uint256 tokenId) {
        require(accounts[tokenId].state != PropertyState.DELETED, "NFT is deleted");
        require(nft.ownerOf(tokenId) == msg.sender, "You must be the holder of the NFT");
        _;
    }

    modifier inState(uint256 id, PropertyState state) {
        require(accounts[id].state == state, "Currently in incorrect state");
        _;
    }
}
