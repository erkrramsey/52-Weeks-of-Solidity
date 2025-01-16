// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC-AutoRebase Token
 * @dev ERC-20 compliant token with automatic rebasing functionality.
 * Rebasing adjusts the total supply at regular intervals, scaling all holders' balances proportionally.
 */
contract ERCAutoRebase {
    // ERC-20 standard variables
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    // Total supply before scaling
    uint256 private _initialTotalSupply;

    // Scaling factor to manage rebases
    uint256 private _scalingFactor;

    // Mapping from account to scaled balance
    mapping(address => uint256) private _scaledBalances;

    // Mapping for allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // Rebase variables
    uint256 public lastRebaseTime;
    uint256 public rebaseInterval; // in seconds
    uint256 public rebaseRate; // e.g., 2 for 2%

    // Owner address for access control
    address public owner;

    // Events as per ERC-20 standard
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 newTotalSupply, uint256 scalingFactor);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Constructor initializes the token with initial supply and sets rebase parameters.
     * @param _name Token name.
     * @param _symbol Token symbol.
     * @param initialSupply Initial token supply (in smallest unit, considering decimals).
     * @param _rebaseInterval Time interval between rebases (in seconds).
     * @param _rebaseRate Percentage rate for each rebase (e.g., 2 for 2%).
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 initialSupply,
        uint256 _rebaseInterval,
        uint256 _rebaseRate
    ) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;

        _initialTotalSupply = initialSupply;
        _scalingFactor = 1e18; // Start with a scaling factor of 1 (scaled by 1e18 for precision)
        _scaledBalances[msg.sender] = _initialTotalSupply * 1e18;

        rebaseInterval = _rebaseInterval;
        rebaseRate = _rebaseRate;
        lastRebaseTime = block.timestamp;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /**
     * @dev Returns the total supply after applying the scaling factor.
     */
    function totalSupply() public view returns (uint256) {
        return (_initialTotalSupply * _scalingFactor) / 1e18;
    }

    /**
     * @dev Returns the balance of a specific account after applying the scaling factor.
     * @param account The address of the account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return (_scaledBalances[account] * _scalingFactor) / 1e18;
    }

    /**
     * @dev Transfers tokens from the caller to a recipient.
     * @param to The recipient address.
     * @param amount The amount to transfer (in token units).
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` can spend on behalf of `owner`.
     * @param owner_ The owner address.
     * @param spender The spender address.
     */
    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
    }

    /**
     * @dev Approves `spender` to spend `amount` on behalf of the caller.
     * @param spender The spender address.
     * @param amount The amount to approve (in token units).
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from `from` to `to` using the allowance mechanism.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount to transfer (in token units).
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC-AutoRebase: transfer amount exceeds allowance");
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        return true;
    }

    /**
     * @dev Internal function to handle transfers.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount to transfer (in token units).
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC-AutoRebase: transfer from the zero address");
        require(to != address(0), "ERC-AutoRebase: transfer to the zero address");
        require(balanceOf(from) >= amount, "ERC-AutoRebase: transfer amount exceeds balance");

        uint256 scaledAmount = (amount * 1e18) / _scalingFactor;

        _scaledBalances[from] -= scaledAmount;
        _scaledBalances[to] += scaledAmount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal function to approve allowances.
     * @param owner_ The owner address.
     * @param spender The spender address.
     * @param amount The amount to approve (in token units).
     */
    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC-AutoRebase: approve from the zero address");
        require(spender != address(0), "ERC-AutoRebase: approve to the zero address");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    /**
     * @dev Triggers a rebase operation if the interval has passed.
     * Can be called by anyone, but execution is restricted by time interval.
     */
    function rebase() external {
        require(block.timestamp >= lastRebaseTime + rebaseInterval, "ERC-AutoRebase: rebase not due yet");

        // Calculate new scaling factor
        // Example: for a 2% increase, scalingFactor = scalingFactor * (1 + 0.02) = scalingFactor * 102 / 100
        uint256 newScalingFactor = (_scalingFactor * (100 + rebaseRate)) / 100;

        // Update scaling factor
        _scalingFactor = newScalingFactor;

        // Update total supply
        uint256 newTotalSupply = (_initialTotalSupply * _scalingFactor) / 1e18;
        _initialTotalSupply = (_initialTotalSupply * (100 + rebaseRate)) / 100;

        lastRebaseTime = block.timestamp;

        emit Rebase(newTotalSupply, _scalingFactor);
    }

    /**
     * @dev Allows the owner to set a new rebase interval.
     * @param _newInterval The new rebase interval (in seconds).
     */
    function setRebaseInterval(uint256 _newInterval) external onlyOwner {
        require(_newInterval >= 1 minutes, "ERC-AutoRebase: interval too short");
        rebaseInterval = _newInterval;
    }

    /**
     * @dev Allows the owner to set a new rebase rate.
     * @param _newRate The new rebase rate (percentage, e.g., 2 for 2%).
     */
    function setRebaseRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 100, "ERC-AutoRebase: rebase rate too high");
        rebaseRate = _newRate;
    }

    /**
     * @dev Allows the owner to transfer ownership to a new address.
     * @param newOwner The new owner address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ERC-AutoRebase: new owner is the zero address");
        owner = newOwner;
    }
}
