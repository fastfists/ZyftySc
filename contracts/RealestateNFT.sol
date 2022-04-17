pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RealestateNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;

    mapping (uint256 => string) private _tokenURIs;

    struct Lean {
        uint256 value;
        address leanProvider;
        bool dynamicCost;

        address assetType;
    }

    struct Account {
        // uint256 thresholdLean;
        uint256 reserve;
        Lean primaryLean; // id 0
        Lean lean2;
        Lean lean3;

        Counters.Counter leanCount;
    }

    mapping(uint256 => Account) accounts;

    constructor()
        ERC721("RealestateNFT", "RNFT")
    {}
    
    // Only the Escrow contract can mint this NFT
    function mint(address recipient, string memory meta_data_uri, address leanProvider, address leanAssetType)
        public
        returns(uint256)
        {

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, meta_data_uri);

        accounts[newItemId] = Account({
            // uint256 thresholdLean;
            reserve : 0,
            primaryLean: Lean(
                0,
                leanProvider,
                true,
                leanAssetType
            ),
            lean2: Lean(0, address(0), false, address(0)),
            lean3: Lean(0, address(0), false, address(0)),
            leanCount: Counters.Counter(1)
        });
        
        return newItemId;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
      internal
      virtual
    {
      _tokenURIs[tokenId] = _tokenURI;
    }

    function increaseReserve(uint256 tokenID) public payable {
        accounts[tokenID].reserve += msg.value;
    }

    function redeemReserve(uint256 tokenID, uint256 value) 
        public 
        {
        address owner = ownerOf(tokenID);
        require(msg.sender == owner);
        require(accounts[tokenID].reserve >= value);
        payable(owner).transfer(value);
        accounts[tokenID].reserve -= value;
    }

    function getLean(uint256 tokenID, uint8 leanID)
        public
        view
        returns(Lean memory)
        {
        if (leanID == 1) return accounts[tokenID].primaryLean;
        else if (leanID == 2) return accounts[tokenID].lean2;
        else return accounts[tokenID].lean3; // leandID == 3
    }

    function addLean(uint256 tokenID, uint256 value, address leanProvider, bool dynamicCost, address assetType)
        public
        returns(uint8) {
        require(msg.sender == ownerOf(tokenID));
        accounts[tokenID].leanCount.increment();
        uint8 leanId = uint8(accounts[tokenID].leanCount.current());
        if (leanId == 2) {
            accounts[tokenID].lean2 = Lean({value: value, leanProvider: leanProvider, dynamicCost: dynamicCost, assetType: assetType});
        } else // (leanId == 3) {
            accounts[tokenID].lean3 = Lean({value: value, leanProvider: leanProvider, dynamicCost: dynamicCost, assetType: assetType});
        
        return leanId;
    }

    // Changes lean1 by adding or subtract delta, requires owners signature
    function payLean(uint256 tokenID, uint8 leanID, address assetType, uint256 amount)
        public
        payable
        returns(uint256)
        {
        require(msg.sender == ownerOf(tokenID));
        Lean memory l = getLean(tokenID, leanID);
        require(assetType == l.assetType, "Incorrect asset type");
        IERC20 token = IERC20(l.assetType);
        if (amount > l.value)
            amount = l.value;
        require(token.allowance(msg.sender, address(this)) >= amount, "Insuffecient Funds");
        token.transferFrom(msg.sender, l.leanProvider, amount);
        setLean(tokenID, leanID, l.value - amount);
        return l.value - amount;
    }

    modifier onlyLeanProviderOf(uint256 tokenID, uint8 leanID) {
        require(getLean(tokenID, leanID).leanProvider == msg.sender, "You are not the lean provider");
        _;
    }

    function increaseLean(uint256 tokenID, uint8 leanID, uint256 amount) 
        public
        onlyLeanProviderOf(tokenID, leanID)
        {
        Lean memory l = getLean(tokenID, leanID);
        require(l.dynamicCost, "Lean is static cost only");
        setLean(tokenID, leanID, l.value + amount);
    }

    function setLean(uint256 tokenID, uint8 leanID, uint256 value)
        internal
        {
        if (leanID == 1)
            accounts[tokenID].primaryLean.value = value;
        else if (leanID == 2)
            accounts[tokenID].lean2.value = value;
        else // if (leanID == 3)
            accounts[tokenID].lean3.value = value;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenID
    ) internal override {
        // Require 1st lean to be satisified
        require(accounts[tokenID].primaryLean.value == 0); 
    }

}
