// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./Ownable.sol";

contract DanapayToken is Ownable {
    uint256 public minBalanceForAccounts;

    mapping(address => uint256) _balances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 indexed transactionId
    );

    event BulkTransfer(
        uint256 indexed transactionId
    );

    event Deposit(
        address indexed sender,
        uint256 value
    );

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(uint256 initialSupply) {
        _name = "Danacoin";
        _symbol = "DCN";

        mintTokens(initialSupply, 0);
    }

    /*
     *  Modifiers
     */
    modifier hasEnoughEther(uint256 _amount) {
        require(
            address(this).balance >= _amount,
            "Contract does not have enough ether."
        );
        _;
    }

    /**
     * @dev receive function allows to deposit ether.
     */
    receive() external payable {
        if (msg.value > 0) emit Deposit(_msgSender(), msg.value);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure returns (uint8) {
        return 7;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        require(
            newOwner != owner(),
            "Ownable: New owner should not be current owner"
        );
        // we first tranfer the owner tokens to the new owner
        _balances[newOwner] += balanceOf(owner());
        _balances[owner()] = 0;

        _transferOwnership(newOwner);
    }

    /**
     * @dev Get the total number of tokens available.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of an account.
     */
    function contractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Gets the balance of an account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /** @dev Creates `amount` tokens and assigns them to `owner`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - only owner is allowed to mint tokens.
     */
    function mintTokens(uint256 amount, uint256 transactionId) public onlyOwner {
        address account = owner();

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount, transactionId);
    }

    /**
     * Set ether minimum balance for an account (1finney = 0.001 eth)
     * finney is deprecated, we now use the equivalent value i.e 1e15
     **/
    function setMinBalance(uint256 minimumBalanceInFinney) public onlyOwner {
        // minBalanceForAccounts = minimumBalanceInFinney * 1 finney;
        minBalanceForAccounts = minimumBalanceInFinney * 1e15;
    }

    /**
     * Fund user account with ethers to be able to execute transactions
     **/
    function initialFundAccount(address payable _account)
        public
        onlyOwner
        hasEnoughEther(minBalanceForAccounts)
    {
        _account.transfer(minBalanceForAccounts);
    }

    /**
     * Refund user account with necessary ether to execute transactions
     **/
    function fundAccount(address payable _account)
        public
        onlyOwner
        hasEnoughEther(minBalanceForAccounts)
        returns (uint256)
    {
        uint256 topUp = 0;

        if (minBalanceForAccounts > _account.balance) {
            topUp = minBalanceForAccounts - _account.balance;
            payable(_msgSender()).transfer(topUp);
        }

        return topUp; // Returns the amount of added ether
    }

    /**
     * @dev Destroys `amount` tokens from owner account, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - owner account must have at least `amount` tokens.
     */
    function _burn(uint256 amount) internal onlyOwner {
        address account = owner();

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount, 0);
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            recipient != sender,
            "ERC20: sender and receiver should not be the same"
        );

        uint256 senderBalance = balanceOf(sender);
        require(senderBalance >= amount, "ERC20: Not enough tokens");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        // fundAccount(payable(sender)); // Refund the account ether using the contract
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(
        address payable _to,
        uint256 _value,
        uint256 _transactionId) public {
        _transfer(_msgSender(), _to, _value);
        emit Transfer(_msgSender(), _to, _value, _transactionId);
    }

    function bulkTransfer(
        address[] memory _tos,
        uint256[] memory _values,
        uint256 _transactionId) public {
        require(_tos.length == _values.length, "Invalid Param");

        for(uint256 i = 0; i< _tos.length;i++) {
            _transfer(_msgSender(), _tos[i], _values[i]);
        }
        // emit BulkTransfer(_msgSender(), _tos, _values, _transactionId);
        emit BulkTransfer(_transactionId);
    }
}
