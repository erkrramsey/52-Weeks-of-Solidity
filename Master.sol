// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin Contracts
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Added Import for IERC721
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERCInteroperableNFT
 * @dev ERC-721 compliant contract where each master NFT can own/control other NFTs.
 */
contract ERCInteroperableNFT is
    ERC721Enumerable,
    ReentrancyGuard,
    IERC721Receiver,
    Ownable(msg.sender)
{
    using Counters for Counters.Counter;
    Counters.Counter private _masterCounter;

    // Struct representing a child NFT
    struct ChildNFT {
        address contractAddress;
        uint256 tokenId;
    }

    // Struct representing a master NFT
    struct MasterNFT {
        address owner;
        ChildNFT[] lockedTokens;
    }

    // Mapping from master NFT ID to its details
    mapping(uint256 => MasterNFT) private masterNFTs;

    // Mapping from master NFT ID to token URI
    mapping(uint256 => string) private _tokenURIs;

    // Events
    event MasterCreated(uint256 indexed masterId, address indexed owner);
    event LockedNFT(
        uint256 indexed masterId,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event ReleasedNFT(
        uint256 indexed masterId,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event TransferMasterNFT(
        uint256 indexed masterId,
        address indexed from,
        address indexed to
    );

    /**
     * @dev Constructor to set the name and symbol of the master NFT collection.
     */
    constructor() ERC721("Interoperable NFT", "INFT") {}

    /**
     * @dev Creates a new master NFT and mints it to the caller.
     * @param tokenURI_ Metadata URI for the master NFT.
     * @return masterId The ID of the newly created master NFT.
     */
    function createMasterNFT(string memory tokenURI_)
        external
        nonReentrant
        returns (uint256 masterId)
    {
        _masterCounter.increment();
        masterId = _masterCounter.current();
        _safeMint(msg.sender, masterId);
        _tokenURIs[masterId] = tokenURI_;

        masterNFTs[masterId].owner = msg.sender;

        emit MasterCreated(masterId, msg.sender);
    }

    /**
     * @dev Returns the token URI for a given token ID.
     * @param tokenId The token ID to query.
     * @return The token URI string.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            IERC721(msg.sender).ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI set of nonexistent token"
        );

        return _tokenURIs[tokenId];
    }

    /**
     * @dev Sets the token URI for a given token ID.
     * Only the owner of the contract can set the token URI.
     * @param tokenId The token ID to set its URI.
     * @param tokenURI_ The token URI string.
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI_)
        external
        onlyOwner
    {
        require(
            IERC721(msg.sender).ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = tokenURI_;
    }

    /**
     * @dev Internal function to check if a contract address supports the ERC721 interface.
     * @param nftAddress Address of the NFT contract to check.
     * @return bool Whether the contract supports ERC721.
     */
    function _isERC721(address nftAddress) internal view returns (bool) {
        try
            IERC721(nftAddress).supportsInterface(type(IERC721).interfaceId)
        returns (bool isSupported) {
            return isSupported;
        } catch {
            return false;
        }
    }

    /**
     * @dev Locks a child NFT into a master NFT.
     * The master NFT must be owned by the caller.
     * The child NFT is transferred to this contract and associated with the master NFT.
     * @param masterId The ID of the master NFT.
     * @param nftAddress The contract address of the child NFT.
     * @param tokenId The token ID of the child NFT.
     */
    function lockNFT(
        uint256 masterId,
        address nftAddress,
        uint256 tokenId
    ) external nonReentrant {
        require(
            IERC721(msg.sender).ownerOf(masterId) != address(0),
            "Master NFT does not exist"
        );
        require(
            ownerOf(masterId) == msg.sender,
            "Caller is not the owner of the master NFT"
        );
        require(_isERC721(nftAddress), "Address does not support ERC721");
        require(
            IERC721(nftAddress).ownerOf(tokenId) == msg.sender,
            "Caller does not own the child NFT"
        );

        // Transfer the child NFT to this contract
        IERC721(nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        // Add to locked tokens
        masterNFTs[masterId].lockedTokens.push(
            ChildNFT({contractAddress: nftAddress, tokenId: tokenId})
        );

        emit LockedNFT(masterId, nftAddress, tokenId);
    }

    /**
     * @dev Releases a locked child NFT from a master NFT.
     * The master NFT must be owned by the caller.
     * The child NFT is transferred back to the caller.
     * @param masterId The ID of the master NFT.
     * @param nftAddress The contract address of the child NFT.
     * @param tokenId The token ID of the child NFT.
     */
    function releaseNFT(
        uint256 masterId,
        address nftAddress,
        uint256 tokenId
    ) external nonReentrant {
        require(
            IERC721(msg.sender).ownerOf(masterId) != address(0),
            "Master NFT does not exist"
        );
        require(
            ownerOf(masterId) == msg.sender,
            "Caller is not the owner of the master NFT"
        );

        ChildNFT[] storage locked = masterNFTs[masterId].lockedTokens;
        bool found = false;
        uint256 index;

        // Find the child NFT in the locked tokens
        for (uint256 i = 0; i < locked.length; i++) {
            if (
                locked[i].contractAddress == nftAddress &&
                locked[i].tokenId == tokenId
            ) {
                found = true;
                index = i;
                break;
            }
        }

        require(found, "Child NFT not locked in this master NFT");

        // Remove the child NFT from the locked tokens
        locked[index] = locked[locked.length - 1];
        locked.pop();

        // Transfer the child NFT back to the caller
        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit ReleasedNFT(masterId, nftAddress, tokenId);
    }

    /**
     * @dev Returns the list of child NFTs locked in a master NFT.
     * @param masterId The ID of the master NFT.
     * @return An array of ChildNFT structs.
     */
    function getLockedNFTs(uint256 masterId)
        external
        view
        returns (ChildNFT[] memory)
    {
        require(
            IERC721(msg.sender).ownerOf(masterId) != address(0),
            "Master NFT does not exist"
        );
        return masterNFTs[masterId].lockedTokens;
    }

    /**
     * @dev Overrides the _beforeTokenTransfer hook from ERC721 to handle ownership changes.
     * Ensures that the masterNFTs mapping reflects the new owner.
     * @param from The address transferring the token.
     * @param to The address receiving the token.
     * @param tokenId The token ID being transferred.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        // If the token is being minted
        if (from == address(0)) {
            return;
        }

        // If the token is being burned
        if (to == address(0)) {
            ChildNFT[] storage locked = masterNFTs[tokenId].lockedTokens;
            for (uint256 i = 0; i < locked.length; i++) {
                IERC721(locked[i].contractAddress).safeTransferFrom(
                    address(this),
                    from,
                    locked[i].tokenId
                );
                emit ReleasedNFT(
                    tokenId,
                    locked[i].contractAddress,
                    locked[i].tokenId
                );
            }
            delete masterNFTs[tokenId];
        }

        // If the token is being transferred to another address
        if (from != msg.sender) {
            require(
                msg.sender == ownerOf(tokenId),
                "Only the NFT Owner can transfer"
            );
        } else {
            emit TransferMasterNFT(tokenId, from, to);
        }
    }

    /*
     * @dev Implements the ERC721Receiver interface to accept safe transfers of child NFTs.
     * Ensures that the child NFT is intended to be locked into a master NFT.
     * @param operator The address which called `safeTransferFrom`. (Unused)
     * @param from The address which previously owned the token.
     * @param tokenId The NFT identifier which is being transferred.
     * @param data Additional data with no specified format. Encoded as (masterId).
     * @return bytes4 Return value indicating successful receipt of the NFT.
     */
    function onERC721Received(
        address, // operator (unused)
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Decode the masterId from data
        require(data.length == 32, "Invalid data for masterId");
        uint256 masterId = abi.decode(data, (uint256));

        require(
            IERC721(msg.sender).ownerOf(masterId) != address(0),
            "Master NFT does not exist"
        );
        require(
            ownerOf(masterId) == from,
            "Sender is not the owner of the master NFT"
        );

        // Add to locked tokens
        masterNFTs[masterId].lockedTokens.push(
            ChildNFT({contractAddress: msg.sender, tokenId: tokenId})
        );

        emit LockedNFT(masterId, msg.sender, tokenId);

        return this.onERC721Received.selector;
    }

    /**
     * @dev Overrides the supportsInterface function to include interfaces from inherited contracts.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return bool Whether the contract implements the requested interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
