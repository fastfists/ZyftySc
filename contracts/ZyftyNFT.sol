pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "contracts/Lien/ILien.sol";

contract ZyftyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;

    event LienAdded(uint256 indexed tokenID, uint256 lienID, address lienAddress);
    event LienChanged(uint256 indexed tokenID, uint256 lienID, address lienAddress);
    event LienProposed(uint256 indexed tokenID, address lienAddress);
    event LienChangeProposed(uint256 indexed tokenID, address lienAddress, uint256 position);

    struct Account {
        uint256 reserve;
        address asset;
        address primaryLien; // id 0
        address proposedLien;
        uint8 proposedLienSlot;
        uint8 lienCount;
    }

    mapping(uint256 => Account) accounts;

    // These indexes should range from 1-4
    //      tokenID            lienID     lien
    mapping(uint256 => mapping(uint256 => address)) secondaryLiens;
    mapping(uint256 => string) _tokenURIs;

    address private escrow;

    constructor(address _escrow)
        ERC721("ZyftyNFT", "ZNFT")
        {
        escrow = _escrow;
    }
    
    function mint(address recipient, string memory meta_data_uri, address _primaryLien)
        public
        returns(uint256)
        {

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, meta_data_uri);

        accounts[newItemId] = Account({
            // uint256 thresholdLien;
            reserve : 0,
            asset: ILien(_primaryLien).asset(),
            primaryLien: _primaryLien,
            proposedLien: address(0),
            proposedLienSlot: 0,
            lienCount: 1
        });
        
        return newItemId;
    }

    function proposeLienTransfer(uint256 tokenID, uint8 lienID, address newLienAddress) public {
        require(ILien(getLien(tokenID, lienID)).lienProvider() == msg.sender, "You are not the old lien provider");

        Account storage acc = accounts[tokenID];
        ILien newLien = ILien(newLienAddress);
        require(newLien.asset() == asset(tokenID), "The asset type of this lien must be the asset type of the contract");
        acc.proposedLien = newLienAddress;
        acc.proposedLienSlot = lienID;
        emit LienProposed(tokenID, newLienAddress);
    }

    /**
     * @dev Accepts the currently proposed lien as a transfer
     *      for the token `id`. This must be set using proposeLienTransfer
     *      The lien address must be passed as `confirmLienAddress`. The sender of the message
     *      must be the message sender.
     */
    function acceptLienTransfer(uint256 id, address confirmLienAddress) public {
        Account storage acc = accounts[id];
        require(acc.proposedLienSlot != 0, "This is a lien transfer, cannot confirm through this.");
        require(acc.proposedLien == confirmLienAddress, "Lien address accepted is not the one proposed");
        ILien lien = ILien(confirmLienAddress);
        require(msg.sender == lien.lienProvider(), "Only the lien provider can accept this lien");

        acc.lienCount += 1;
        require(acc.lienCount <= 4, "Only 4 liens are allowed");
        uint8 maxID = 3;
        uint256 lienID = 1;
        // Find next empty slot
        mapping(uint256 => address) storage lienCopy = secondaryLiens[id];
        // WARNING, this is very dangerous.
        // Please ensure 100% that an empty
        // slot is available when doing this.
        while (lienCopy[lienID] != address(0)){
            lienID++;
        }

        secondaryLiens[id][lienID] = confirmLienAddress;
        acc.proposedLienSlot = 0;
        emit LienAdded(id, lienID, confirmLienAddress);
    }

    /**
     * @dev Proposes a lien `lienID` for token `tokenID`
     *      lien.asset() must be the same as `asset(tokenID)`
     *      If the token already has 4 liens, the transaction
     *      will be reverted.
     *      This can only be called by 'ownerOf(tokenID)`
     */
    function proposeLien(uint256 tokenID, address lienAddress) public {
        require(ownerOf(tokenID) == msg.sender, "Must be the owner");
        Account storage acc = accounts[tokenID];
        require(acc.lienCount < 4, "No more than 4 liens are allowed");
        ILien lien = ILien(lienAddress);
        require(lien.asset() == asset(tokenID), "The asset type of this lien must be the asset type of the contract");
        acc.proposedLien = lienAddress;
        acc.proposedLienSlot = 0;
        emit LienProposed(tokenID, lienAddress);
    }

    /**
     * @dev Accepts the currently proposed lien on the
     *      for the token `id`. The lien address must be passed
     *      as `confirmLienAddress`. The sender of the message
     *      must be `lien.lienProvider()`.
     */
    function acceptLien(uint256 id, address confirmLienAddress) public {
        Account storage acc = accounts[id];
        require(acc.proposedLienSlot == 0, "This is a lien transfer, cannot confirm through this.");
        require(acc.proposedLien == confirmLienAddress, "Lien address accepted is not the one proposed");
        ILien lien = ILien(confirmLienAddress);
        require(msg.sender == lien.lienProvider(), "Only the lien provider can accept this lien");

        acc.lienCount += 1;
        require(acc.lienCount <= 4, "Only 4 liens are allowed");
        uint8 maxID = 3;
        uint256 lienID = 1;
        // Find next empty slot
        mapping(uint256 => address) storage lienCopy = secondaryLiens[id];
        // WARNING, this is very dangerous.
        // Please ensure 100% that an empty
        // slot is available when doing this.
        while (lienCopy[lienID] != address(0)){
            lienID++;
        }

        secondaryLiens[id][lienID] = confirmLienAddress;
        acc.proposedLien = address(0);
        emit LienAdded(id, lienID, confirmLienAddress);
    }


    function increaseReserve(uint256 tokenID, uint256 amount) public {
        // Reserve account must use same account as primary lean account
        // Assuming that the asset type of the primary lien does not change
        IERC20 token = IERC20(asset(tokenID));
        token.transferFrom(msg.sender, address(this), amount);
        accounts[tokenID].reserve += amount;
    }

    /**
     * @dev Redeems `amount` from the reserve and gives the value to the owner
     *      only the owner can access this.
     *      
     *      If the amount is greater than the reserve account, then it returns
     *      all funds from the reserve account instead
     */
    function redeemReserve(uint256 tokenID, uint256 amount) public {
        require(ownerOf(tokenID) == msg.sender);
        Account storage acc = accounts[tokenID];
        if (amount > acc.reserve) {
            amount = acc.reserve;
        }
        IERC20(asset(tokenID)).transfer(msg.sender, amount);
        acc.reserve -= amount;
    }

    /**
     * Pays the full amount of the lien used from the reserve account
     * returns the amount the contract sent to the lien, on error or 
     * if the lien is fully paid out 0 is returned.
     */
    function payLienFull(uint256 tokenID, uint256 lienID)
        public
        returns(uint256)
        {
        require(msg.sender == ownerOf(tokenID) || msg.sender == escrow, "You must be the owner or the escrow");
        address lienAddr = getLien(tokenID, lienID);
        require(lienAddr != address(0), "Lien does not exist");
        ILien(lienAddr).update();
        uint256 amount = ILien(lienAddr).balance();
        return payLien(tokenID, tokenID, amount);
    }

    /**
     * Pays the full amount of the lien used from the reserve account
     * returns the amount the contract sent to the lien, on error or 
     * if the lien is fully paid out 0 is returned.
     */
    function payLien(uint256 tokenID, uint256 lienID, uint256 amount)
        public
        returns (uint256)
        {
        
        address lienAddr = getLien(tokenID, lienID);
        require(lienAddr != address(0), "Lien does not exist");
        ILien l = ILien(lienAddr);
        Account storage acc = accounts[tokenID];
        if (amount > acc.reserve) {
            amount = acc.reserve;
        }
        IERC20(asset(tokenID)).approve(lienAddr, amount);
        uint256 remainder = l.pay(amount);
        acc.reserve -= (amount - remainder);
        return amount - remainder;
    }

    /**
     * @dev Removes the lien ID, requires the lienProviders
     *      permission
     */
    function removeLien(uint256 tokenID, uint256 lienID)
        public 
        onlyLienProviderOf(tokenID, lienID) {

        require(lienID > 0, "Cannot remove primary Lien");
        accounts[tokenID].lienCount -= 1;
        delete secondaryLiens[tokenID][lienID];
    }

    /**
     * Iterates through all the accounts and
     * updates the lien accounts
     */
    function updateLiens(uint256 tokenID)
        public
        returns(uint256 totalCost)
        {

        totalCost = 0;
        uint8 count = accounts[tokenID].lienCount;
        uint8 numFound = 0;
        for (uint256 i = 0; numFound < count; i++) {
            address l = getLien(tokenID, i);
            if (l != address(0)) {
                numFound++;
                try ILien(l).balance() returns (uint256 bal) {
                    totalCost += bal;
                }
                catch{}
            }
        }
    }

    /**
     * Pulls funds from the reserve account to
     * fund the primary account first, then
     * secondary accounts
     */
    function balanceAccounts(uint256 tokenID)
        public
        {
        require(msg.sender == ownerOf(tokenID) || msg.sender == escrow);
        uint8 count = accounts[tokenID].lienCount;
        uint8 numFound = 0;
        for (uint256 i = 0; numFound < count; i++) {
            if (getLien(tokenID, i) != address(0)) {
                numFound++;
                payLienFull(tokenID, i);
            }
        }
    }

    /**
     * @dev Destroyes the NFT specified by id
     */
    function destroyNFT(uint256 id)
        public
        onlyOwner {

        _burn(id);
        uint end = 4;
        for (uint i = 1; i <= end; i++) {
            delete secondaryLiens[id][i];
        }
        delete accounts[id];
    }

    /**
     * @dev Returns the asset type that token `id` uses,
     *      each NFT only uses a single asset.
     */
    function asset(uint256 id)
        public
        view
        returns(address addr) {
        addr = accounts[id].asset;
    }

    /**
     * @dev Returns the account of the tokenID specified
     */
    function getAccount(uint256 tokenID) 
        public
        view
        returns(Account memory){

        return accounts[tokenID];
    }

    /**
     * @dev Sets the tokenURI
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
      internal
      virtual
    {
      _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 id)
        public
        override
        view
        returns(string memory){
        return _tokenURIs[id];
    }

    /**
     * @dev Returns the lien specified by `tokenID` and `lienID`,
     *      the lienID of the primary lien is 0.
     */
    function getLien(uint256 tokenID, uint256 lienID)
        public
        view
        returns(address)
        {
        if (lienID == 0) return accounts[tokenID].primaryLien;
        return secondaryLiens[tokenID][lienID];
    }

    /**
     * @dev Returns the lien specified by `tokenID` and `lienID`,
     *      the lienID of the primary lien is 0.
     */
    function getSecondaryLiens(uint256 tokenID)
        public
        view
        returns(mapping(uint8 => address) memory)
        {
        mapping(uint8 => address) storage addrs;
        for (uint8 i = 1; i < 4; i++ ) {
            addrs[i] = getLien(tokenID, i);
        }
    }

    function getReserve(uint256 id) 
        public
        view
        returns (uint256 reserve){
        reserve = accounts[id].reserve;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenID
    ) internal override {
        // Require 1st lien to be satisified
        require(from == address(0) || to == address(0) || from == escrow || to == escrow, "Token must be passed through Sales Contract");
    }

    modifier onlyLienProviderOf(uint256 tokenID, uint256 lienID) {
        require(ILien(getLien(tokenID, lienID)).lienProvider() == msg.sender, "You are not the lien provider");
        _;
    }

}
