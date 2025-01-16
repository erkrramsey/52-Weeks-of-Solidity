// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiTokenGraph
 * @dev Allows graphing and connecting ERC-20, ERC-721, and ERC-1155 tokens.
 */
contract MultiTokenGraph is ERC721, Ownable {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Node {
        uint256 nodeId;
        address tokenAddress;
        TokenType tokenType;
        mapping(uint256 => bool) connections;
        string metadata;
        bool exists;
    }

    mapping(uint256 => Node) private _nodes;
    uint256 private _nodeCount;
    mapping(address => bool) private _admins;

    event NodeCreated(
        uint256 indexed nodeId,
        address indexed tokenAddress,
        TokenType tokenType,
        string metadata
    );
    event ConnectionAdded(
        uint256 indexed fromNode,
        uint256 indexed toNode,
        bool bidirectional
    );
    event ConnectionRemoved(
        uint256 indexed fromNode,
        uint256 indexed toNode,
        bool bidirectional
    );
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        _admins[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(_admins[msg.sender], "Not an admin");
        _;
    }

    /**
     * @dev Checks if a node exists.
     */
    function nodeExists(uint256 nodeId) public view returns (bool) {
        return _nodes[nodeId].exists;
    }

    /**
     * @dev Adds an admin for managing the graph.
     */
    function addAdmin(address admin) external onlyOwner {
        _admins[admin] = true;
        emit AdminAdded(admin);
    }

    /**
     * @dev Removes an admin.
     */
    function removeAdmin(address admin) external onlyOwner {
        _admins[admin] = false;
        emit AdminRemoved(admin);
    }

    /**
     * @dev Creates a new node for a token (ERC-20, ERC-721, ERC-1155).
     */
    function createNode(
        address tokenAddress,
        TokenType tokenType,
        string calldata metadata
    )
        internal
        returns (
            uint256 nodeId
        )
    {
        _nodeCount += 1;
        nodeId = _nodeCount;

        _nodes[nodeId].tokenAddress = tokenAddress;
        _nodes[nodeId].tokenType = tokenType;
        _nodes[nodeId].metadata = metadata;
        _nodes[nodeId].exists = true;

        emit NodeCreated(nodeId, tokenAddress, tokenType, metadata);
    }

    /**
     * @dev Batch creation of nodes.
     */
    function batchCreateNodes(
        address[] calldata tokenAddresses,
        TokenType[] calldata tokenTypes,
        string[] calldata metadataArray
    ) external onlyAdmin {
        require(
            tokenAddresses.length == tokenTypes.length &&
            tokenTypes.length == metadataArray.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            createNode(tokenAddresses[i], tokenTypes[i], metadataArray[i]);
        }
    }

    /**
     * @dev Adds a connection between two nodes.
     */
    function addConnection(
        uint256 fromNode,
        uint256 toNode,
        bool bidirectional
    ) internal {
        require(
            nodeExists(fromNode) && nodeExists(toNode),
            "Node does not exist"
        );

        _nodes[fromNode].connections[toNode] = true;
        if (bidirectional) {
            _nodes[toNode].connections[fromNode] = true;
        }

        emit ConnectionAdded(fromNode, toNode, bidirectional);
    }

    /**
     * @dev Adds multiple connections at once.
     */
    function batchAddConnections(
        uint256[] calldata fromNodes,
        uint256[] calldata toNodes,
        bool[] calldata bidirectional
    ) external onlyAdmin {
        require(
            fromNodes.length == toNodes.length &&
            toNodes.length == bidirectional.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < fromNodes.length; i++) {
            addConnection(fromNodes[i], toNodes[i], bidirectional[i]);
        }
    }

    /**
     * @dev Removes a connection.
     */
    function removeConnection(
        uint256 fromNode,
        uint256 toNode,
        bool bidirectional
    ) external onlyAdmin {
        require(
            nodeExists(fromNode) && nodeExists(toNode),
            "Node does not exist"
        );

        _nodes[fromNode].connections[toNode] = false;
        if (bidirectional) {
            _nodes[toNode].connections[fromNode] = false;
        }

        emit ConnectionRemoved(fromNode, toNode, bidirectional);
    }

    /**
     * @dev Retrieves all connected node IDs for a given node.
     */
    function getConnections(uint256 nodeId)
        external
        view
        returns (uint256[] memory)
    {
        require(nodeExists(nodeId), "Node does not exist");

        uint256 count = 0;
        uint256[] memory temp = new uint256[](_nodeCount);

        for (uint256 i = 1; i <= _nodeCount; i++) {
            if (_nodes[nodeId].connections[i]) {
                temp[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = temp[j];
        }

        return result;
    }

    /**
     * @dev Retrieves the metadata for a node.
     */
    function getNode(uint256 nodeId)
        external
        view
        returns (
            address tokenAddress,
            TokenType tokenType,
            string memory metadata
        )
    {
        require(nodeExists(nodeId), "Node does not exist");
        Node storage node = _nodes[nodeId];
        return (node.tokenAddress, node.tokenType, node.metadata);
    }

    /**
     * @dev Retrieves the total number of nodes.
     */
    function totalNodes() external view returns (uint256) {
        return _nodeCount;
    }

    /**
     * @dev Checks if two nodes are connected.
     */
    function isConnected(uint256 fromNode, uint256 toNode)
        external
        view
        returns (bool)
    {
        return _nodes[fromNode].connections[toNode];
    }

    /**
     * @dev Retrieves the number of connections for a given node.
     */
    function getNodeDegree(uint256 nodeId)
        external
        view
        returns (uint256 degree)
    {
        require(nodeExists(nodeId), "Node does not exist");

        uint256 count = 0;
        for (uint256 i = 1; i <= _nodeCount; i++) {
            if (_nodes[nodeId].connections[i]) {
                count++;
            }
        }
        return count;
    }
