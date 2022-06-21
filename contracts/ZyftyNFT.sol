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

    event LienUpdateProposed(uint256 indexed tokenID, address lienAddress);
    event LienUpdated(uint256 indexed tokenID, address oldLienAddress, address newLienAddress);

    struct Account {
        uint256 reserve;
        address asset;
        address primaryLien; // id 0
        address proposedLien;
    }

    mapping(uint256 => Account) accounts;
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
            proposedLien: address(0)
        });
        
        return newItemId;
    }

    /**
     * @dev Proposes to update the NFT `tokenID` with address
     *      `newLienAddress`
     */
    function proposeLienUpdate(uint256 tokenID, address newLienAddress) public {
        Account storage acc = accounts[tokenID];
        require(ILien(acc.primaryLien).lienProvider() == msg.sender, "You are not the old lien provider");

        ILien newLien = ILien(newLienAddress);
        require(newLien.asset() == asset(tokenID), "The asset type of this lien must be the asset type of the contract");
        acc.proposedLien = newLienAddress;
        emit LienUpdateProposed(tokenID, newLienAddress);
    }

    /**
     * @dev Accepts the currently proposed lien as a transfer
     *      for the token `id`. This must be set using proposeLienTransfer
     *      The lien address must be passed as `confirmLienAddress`. The sender of the message
     *      must be the message sender.
     */
    function acceptLienUpdate(uint256 id, address confirmLienAddress) public {
        Account storage acc = accounts[id];
        require(acc.proposedLien != address(0), "No valid lien proposed");
        require(acc.proposedLien == confirmLienAddress, "Lien address accepted is not the one proposed");
        ILien lien = ILien(confirmLienAddress);
        require(msg.sender == lien.lienProvider(), "Only the lien provider can accept this lien");
        address oldLien = acc.primaryLien;
        acc.primaryLien = confirmLienAddress;
        acc.proposedLien = address(0);
        emit LienUpdated(id, oldLien, confirmLienAddress);
    }

    /**
     * @dev Increases the reserve of the NFT of id `tokenID`
     *      by `amount`. The asset used is `asset(tokenID)`
     */
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
        require(ownerOf(tokenID) == msg.sender, "You are not the owner");
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
    function payLienFull(uint256 tokenID)
        public
        returns(uint256)
        {
        require(msg.sender == ownerOf(tokenID), "You must be the owner or the escrow");
        ILien lien = ILien(lien(tokenID));
        uint256 amount = lien.balance();
        return payLien(tokenID, amount);
    }

    /**
     * Pays the full amount of the lien used from the reserve account
     * returns the amount the contract sent to the lien, on error or 
     * if the lien is fully paid out 0 is returned.
     */
    function payLien(uint256 tokenID, uint256 amount)
        public
        returns (uint256)
        {
        address lienAddr = lien(tokenID);
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
     * Iterates through all the accounts and
     * updates the lien accounts
     */
    function updateLien(uint256 tokenID)
        public
        returns(uint256 totalCost)
        {
        totalCost = 0;
        try ILien(lien(tokenID)).balance() returns (uint256 bal) {
            totalCost += bal;
        }
        catch{}
    }

    /**
     * Pulls funds from the reserve account to
     * fund the primary account first, then
     * secondary accounts
     */
    function balanceAccounts(uint256 tokenID)
        public
        {
        require(msg.sender == ownerOf(tokenID) || msg.sender == escrow, "You must be the owner");
        // Pay out the primary LienAccount
        payLienFull(tokenID);
    }

    /**
     * @dev Destroyes the NFT specified by id
     */
    function destroyNFT(uint256 id)
        public
        onlyOwner {

        _burn(id);
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
      virtual {
      _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 id)
        public
        override
        view
        returns(string memory) {
        return _tokenURIs[id];
    }

    /**
     * @dev Returns the lien held on the `tokenID`
     */
    function lien(uint256 tokenID)
        public
        view
        returns(address)
        {
        return accounts[tokenID].primaryLien;
    }

    function getReserve(uint256 id) 
        public
        view
        returns (uint256 reserve) {
        reserve = accounts[id].reserve;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenID
    ) internal override {
        // Require that this can only be transfered via the escrow contract
        require(from == address(0) || to == address(0) || from == escrow || to == escrow, "Token must be passed through Sales Contract");
    }

}
