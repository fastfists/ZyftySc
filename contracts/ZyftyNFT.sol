pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ZyftyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;


    struct Lien {
        uint256 value;
        address lienProvider;
        bool dynamicCost;

        address assetType;
    }

    struct Account {
        // uint256 thresholdLien;
        uint256 reserve;
        Lien primaryLien; // id 0
        Counters.Counter lienCount;
        Counters.Counter nextLien;
    }

    mapping(uint256 => Account) accounts;
    //      tokenID            lienID     lien
    mapping(uint256 => mapping(uint256 => Lien)) secondaryLiens;
    mapping(uint256 => string) _tokenURIs;

    address private escrow;
    address private admin;

    constructor(address zyftyRoylatiesAcc, address _escrow)
        ERC721("ZyftyNFT", "ZNFT")
        {
        admin = zyftyRoylatiesAcc;
        escrow = _escrow;
    }
    
    function mint(address recipient, string memory meta_data_uri, address lienProvider, address lienAssetType)
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
            primaryLien: Lien( // id 0
                0,
                lienProvider,
                true,
                lienAssetType
            ),
            lienCount: Counters.Counter(1),
            nextLien: Counters.Counter(0)
        });
        
        return newItemId;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
      internal
      virtual
    {
      _tokenURIs[tokenId] = _tokenURI;
    }

    function addLien(uint256 tokenID, address asset, uint256 value, address provider, bool isDynamic) 
    public
    {
        require(ownerOf(tokenID) == msg.sender);
        Account storage acc = accounts[tokenID];
        uint8 num = acc.lienCount.current();
        require(num < 4, "No more than 4 liens are allowed");
        acc.lienCount.increment();
        acc.nextLien.increment();
        
        secondaryLiens[tokenID][acc.nextLien.current()] = Lien({
            value: value, 
            lienProvider: provider,
            dynamicCost: isDynamic,
            assetType: asset
        });
    }

    function increaseReserve(uint256 tokenID, uint256 amount) public {
        // Reserve account must use same account as primary lean account
        // Assuming that the asset type of the primary lien does not change
        IERC20 token = IERC20(accounts[tokenID].primaryLien.assetType);
        token.transferFrom(msg.sender, address(this), amount);
        accounts[tokenID].reserve += amount;
    }

    function increaseLien(uint256 tokenID, uint256 lienID, uint256 amount) 
        public
        onlyLienProviderOf(tokenID, lienID)
        {
        Lien memory l = getLien(tokenID, lienID);
        require(l.dynamicCost == true, "Lien is parametric cost only");
        setLien(tokenID, lienID, l.value + amount);
    }

    function balanceAccounts(uint256 tokenID)
        public
        onlyOwner {
        uint256 res = accounts[tokenID].reserve;
        Lien memory l = accounts[tokenID].primaryLien;
        uint256 debt = l.value;
        IERC20 token = IERC20(l.assetType);
        if (res > 0 && debt > 0) {
            if (res >= debt) {
                // More in reserve account, debt will become zero
                token.transfer(l.lienProvider, debt);
                accounts[tokenID].reserve = res - debt;
                accounts[tokenID].primaryLien.value = 0;
            } else {
                // More in debt account, reserve will become zero
                token.transfer(l.lienProvider, res);
                accounts[tokenID].reserve = 0;
                accounts[tokenID].primaryLien.value = debt - res;
            }
        }
    }

    function getAccount(uint256 tokenID) 
        public
        view returns(Account memory){

        return accounts[tokenID];
    }

    function payLien(uint256 tokenID, uint256 lienID, uint256 amount)
        public
        {
        if (lienID == 0) {
            increaseReserve(tokenID, amount);
            return;
        }

        Lien storage l = secondaryLiens[tokenID][lienID];
        IERC20 token = IERC20(l.assetType);
        token.transferFrom(msg.sender, l.lienProvider, amount);

        if (amount >= l.value && l.dynamicCost) {
            // Lien is finished, remove it?
            secondaryLiens[tokenID][lienID].value = 0;
        } else {
            secondaryLiens[tokenID][lienID].value = l.value - amount;
        }

    }

    function removeLien(uint256 tokenID, uint256 lienID)
        public 
        onlyLienProviderOf(tokenID, lienID) {

        require(lienID > 0, "Cannot remove primary Lien");
        delete secondaryLiens[tokenID][lienID];
    }

    function getLien(uint256 tokenID, uint256 lienID)
        public
        view
        returns(Lien memory)
        {
        if (lienID == 0) return accounts[tokenID].primaryLien;
        return secondaryLiens[tokenID][lienID];
    }

    function setLien(uint256 tokenID, uint256 lienID, uint256 value)
        internal
        {
        if (lienID == 0) accounts[tokenID].primaryLien.value = value;
        else {
            secondaryLiens[tokenID][lienID].value = value;
        }
    }

    function destroyNFT(uint256 id) public onlyOwner {
        _burn(id);
        uint end = accounts[id].nextLien.current();
        for (uint i = 0; i < end; i++) {
            delete secondaryLiens[id][i];
        }
        delete accounts[id];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenID
    ) internal override {
        // Require 1st lien to be satisified
        require(from == escrow || to == escrow, "Token must be passed through Sales Contract");
    }

    modifier onlyLienProviderOf(uint256 tokenID, uint256 lienID) {
        require(getLien(tokenID, lienID).lienProvider == msg.sender, "You are not the lien provider");
        _;
    }

}
