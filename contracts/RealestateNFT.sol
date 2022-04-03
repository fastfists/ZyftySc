pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RealestateNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;

    mapping (uint256 => string) private _tokenURIs;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}
    
    // Only the Escrow contract can mint this NFT
    function mint(address recipient, string memory meta_data_uri)
        public
        onlyOwner
        returns(uint256)
        {

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, meta_data_uri);
        
        return newItemId;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
      internal
      virtual
    {
      _tokenURIs[tokenId] = _tokenURI;
    }
    
    function burn(uint256 tokenId)
        public
        onlyOwner
        {
        _burn(tokenId);
    }

}
