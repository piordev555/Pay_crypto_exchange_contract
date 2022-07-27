// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./DanapayToken.sol";

contract MultiSigToken is DanapayToken {
    /*
     *  Events
     */
    event TransactionSubmitted(
        address indexed sender,
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );
    event ExecutionConfirmation(
        address indexed sender,
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );
    event RefundConfirmation(
        address indexed sender,
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );
    event ExecutionRevocation(
        address indexed sender,
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );
    event RefundRevocation(
        address indexed sender,
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );
    event Executed
    (
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );

    event Refunded
    (
        uint256 indexed escrowTransactionId,
        uint256 indexed transactionId
    );

    /*
     *  Storage
     */
    mapping(uint256 => Transaction) public transactions;

    // map transaction to owner confirmations
    mapping(uint256 => mapping(address => bool)) public executeConfirmations;
    mapping(uint256 => mapping(address => bool)) public refundConfirmations;

    uint256 public transactionCount;

    struct Transaction {
        address to;
        address from;
        address escrowManager;
        uint256 value;
        bool executed;
        bool refunded;
    }

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(uint256 _initialSupply) DanapayToken(_initialSupply) {}

    /*
     *  Modifiers
     */
    modifier isTransactionAdmin(uint256 _escrowTransactionId, address _owner) {
        require(
            transactions[_escrowTransactionId].escrowManager == _owner ||
                owner() == _owner,
            "Not Owner of transaction."
        );
        _;
    }
    modifier isTransactionOwner(uint256 _escrowTransactionId, address _owner) {
        require(
            transactions[_escrowTransactionId].from == _owner ||
                transactions[_escrowTransactionId].to == _owner ||
                transactions[_escrowTransactionId].escrowManager == _owner ||
                owner() == _owner,
            "Not Owner of transaction."
        );
        _;
    }
    modifier transactionExists(uint256 _escrowTransactionId) {
        require(
            transactions[_escrowTransactionId].to != address(0),
            "Transaction does not exist."
        );
        _;
    }
    modifier confirmedExecution(uint256 _escrowTransactionId, address owner) {
        require(
            executeConfirmations[_escrowTransactionId][owner],
            "User has not confirmed transaction."
        );
        _;
    }
    modifier confirmedRefund(uint256 _escrowTransactionId, address owner) {
        require(
            refundConfirmations[_escrowTransactionId][owner],
            "User has not confirmed transaction."
        );
        _;
    }
    modifier notConfirmedExecution(uint256 _escrowTransactionId, address owner) {
        require(
            !executeConfirmations[_escrowTransactionId][owner],
            "User has already confirmed transaction execution."
        );
        _;
    }
    modifier notConfirmedRefund(uint256 _escrowTransactionId, address owner) {
        require(
            !refundConfirmations[_escrowTransactionId][owner],
            "User has already confirmed transaction refund."
        );
        _;
    }
    modifier notExecuted(uint256 _escrowTransactionId) {
        require(
            !transactions[_escrowTransactionId].executed,
            "Transaction has already been executed."
        );
        _;
    }
    modifier notRefunded(uint256 _escrowTransactionId) {
        require(
            !transactions[_escrowTransactionId].refunded,
            "Transaction has already been refunded."
        );
        _;
    }
    modifier notNull(address _address) {
        require(_address != address(0), "Address is null.");
        _;
    }

    /*
     * Public functions
     */

    /**
     * @dev Allows an owner to submit and confirm a transaction.
     * @param _destination Transaction target address.
     * @param _value Transaction danacoin value.
     * @param _escrowManager Transaction Escrow manager address.
     * @return _escrowTransactionId Returns transaction ID.
     */
    function submitEscrowTransaction(
        address _destination,
        uint256 _value,
        address _escrowManager,
        uint256 _transactionId
    ) public returns (uint256 _escrowTransactionId) {
        _escrowTransactionId = addTransaction(_destination, _value, _escrowManager, _transactionId);
    }

    /**
     * @dev Allows an owner to confirm a transaction for execution.
     * @param _escrowTransactionId Transaction ID.
     */
    function confirmTransactionExecution(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        notConfirmedExecution(_escrowTransactionId, _msgSender())
    {
        executeConfirmations[_escrowTransactionId][_msgSender()] = true;
        emit ExecutionConfirmation(_msgSender(), _escrowTransactionId, _transactionId);

        if(isExecutionConfirmed(_escrowTransactionId))
            _execute(_escrowTransactionId, _transactionId);

    }

    /**
     * @dev Allows an owner to revoke a confirmation for a transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function revokeExecutionConfirmation(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedExecution(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        executeConfirmations[_escrowTransactionId][_msgSender()] = false;
        emit ExecutionRevocation(_msgSender(), _escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows an owner to confirm a transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function confirmTransactionRefund(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        notConfirmedRefund(_escrowTransactionId, _msgSender())
    {
        refundConfirmations[_escrowTransactionId][_msgSender()] = true;
        emit RefundConfirmation(_msgSender(), _escrowTransactionId, _transactionId);

        if(isRefundConfirmed(_escrowTransactionId))
            _refund(_escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows an owner to revoke a confirmation for a transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function revokeRefundConfirmation(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedRefund(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        refundConfirmations[_escrowTransactionId][_msgSender()] = false;
        emit RefundRevocation(_msgSender(), _escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows a transaction owner to execute a confirmed transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function executeTransaction(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedExecution(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        require(
            isExecutionConfirmed(_escrowTransactionId),
            "Transaction does not yet meet the required number of confimations."
        );

        _execute(_escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows a transaction admin to execute a transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function adminExecuteTransaction(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionAdmin(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        address escrowManager = transactions[_escrowTransactionId].escrowManager;
        require(
            executeConfirmations[_escrowTransactionId][owner()] &&
                executeConfirmations[_escrowTransactionId][escrowManager],
            "Not enough confirmations."
        );

        _execute(_escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows anyone to refund a confirmed transaction.
     * this returns the tokens to the original sender
     * @param _escrowTransactionId Transaction ID.
     */
    function refundTransaction(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedRefund(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        require(
            isRefundConfirmed(_escrowTransactionId),
            "Transaction does not yet meet the required number of confimations."
        );

        _refund(_escrowTransactionId, _transactionId);
    }

    /**
     * @dev Allows a transaction admin to refund a transaction.
     * @param _escrowTransactionId Transaction ID.
     */
    function adminRefundTransaction(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        public
        isTransactionAdmin(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        address escrowManager = transactions[_escrowTransactionId].escrowManager;
        require(
            refundConfirmations[_escrowTransactionId][owner()] &&
                refundConfirmations[_escrowTransactionId][escrowManager],
            "Not enough confirmations."
        );

        _refund(_escrowTransactionId, _transactionId);
    }

    /**
     * @dev Returns the execution confirmation status of a transaction.
     * @param _escrowTransactionId Transaction ID.
     * @return Confirmation status.
     */
    function isExecutionConfirmed(uint256 _escrowTransactionId)
        public
        view
        returns (bool)
    {
        address to = transactions[_escrowTransactionId].to;
        address from = transactions[_escrowTransactionId].from;
        address escrowManager = transactions[_escrowTransactionId].escrowManager;
        return
            executeConfirmations[_escrowTransactionId][from] ||
            (executeConfirmations[_escrowTransactionId][to] &&
            executeConfirmations[_escrowTransactionId][escrowManager]);
    }

    /**
     * @dev Returns the refund confirmation status of a transaction.
     * @param _escrowTransactionId Transaction ID.
     * @return Confirmation status.
     */
    function isRefundConfirmed(uint256 _escrowTransactionId)
        public
        view
        returns (bool)
    {
        address to = transactions[_escrowTransactionId].to;
        address from = transactions[_escrowTransactionId].from;
        address escrowManager = transactions[_escrowTransactionId].escrowManager;
        return
            refundConfirmations[_escrowTransactionId][to] ||
            (refundConfirmations[_escrowTransactionId][from] &&
            refundConfirmations[_escrowTransactionId][escrowManager]);
    }

    /*
     * Internal functions
     */

    /**
     * @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
     * @param _destination Transaction target address.
     * @param _value Transaction danacoin value.
     * @param _escrowManager Transaction Escrow manager address.
     * @return escrowTransactionId Returns transaction ID.
     */
    function addTransaction(
        address _destination,
        uint256 _value,
        address _escrowManager,
        uint256 _transactionId
    )
        internal
        notNull(_destination)
        notNull(_escrowManager)
        returns (uint256 escrowTransactionId)
    {
        require(balanceOf(_msgSender()) >= _value, "Not enough tokens.");

        // check that all the associated addresses are unique so that we are sure to get 3 confirmations
        require(
            _destination != _msgSender(),
            "Sender and recipient should be different."
        );
        require(
            _destination != _escrowManager,
            "Escrow manager should not be the same as recipient."
        );
        require(
            _escrowManager != _msgSender(),
            "Sender and escrow manager should be different."
        );

        // check for possible overflows
        assert(balanceOf(_destination) + _value > balanceOf(_destination));

        // deduct the danacoins from the account of sender
        _balances[_msgSender()] -= _value;
        // send the tokens to the owner
        _balances[owner()] += _value;

        // save the transaction
        escrowTransactionId = transactionCount;
        transactions[escrowTransactionId] = Transaction({
            from: _msgSender(),
            to: _destination,
            escrowManager: _escrowManager,
            value: _value,
            refunded: false,
            executed: false
        });

        transactionCount += 1;
        emit TransactionSubmitted(_msgSender(), escrowTransactionId, _transactionId);
    }

    /**
     * Internal function to execute a transaction that has the required confirmations
     */
    function _execute(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        private
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedExecution(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        transactions[_escrowTransactionId].executed = true;
        address from = transactions[_escrowTransactionId].from;
        address to = transactions[_escrowTransactionId].to;
        uint256 amount = transactions[_escrowTransactionId].value;
        // get the tokens from the owner
        _balances[owner()] -= amount;
        // send the tokens to the receiver
        _balances[to] += amount;

        // fund account only if the initiator is the owner of the contract
        if (_msgSender() == owner()) {
            fundAccount(payable(from)); // Refund the account ether using the contract
        }

        emit Executed(_escrowTransactionId, _transactionId);
    }

    /**
     * Internal function to refund a transaction that has the required confirmations
     */
    function _refund(
        uint256 _escrowTransactionId,
        uint256 _transactionId
        )
        private
        isTransactionOwner(_escrowTransactionId, _msgSender())
        confirmedRefund(_escrowTransactionId, _msgSender())
        notExecuted(_escrowTransactionId)
        notRefunded(_escrowTransactionId)
    {
        transactions[_escrowTransactionId].executed = true;
        address from = transactions[_escrowTransactionId].from;
        uint256 amount = transactions[_escrowTransactionId].value;
        // get the tokens from the owner
        _balances[owner()] -= amount;
        // send the tokens back to the sender
        _balances[from] += amount;

        emit Refunded(_escrowTransactionId, _transactionId);
    }

    /*
     * Web3 call functions
     */

    /**
     * @dev Returns number of execution confirmations of a transaction.
     * @param _escrowTransactionId Transaction ID.
     * @return count Number of confirmations.
     */
    function getExecutionConfirmationCount(
        uint256 _escrowTransactionId
        )
        public
        view
        returns (uint256 count)
    {
        address to = transactions[_escrowTransactionId].to;
        address from = transactions[_escrowTransactionId].from;
        address escrowManager = transactions[_escrowTransactionId].escrowManager;

        if (executeConfirmations[_escrowTransactionId][escrowManager]) {
            count += 1;
        }
        if (executeConfirmations[_escrowTransactionId][to]) {
            count += 1;
        }
        if (executeConfirmations[_escrowTransactionId][from]) {
            count += 1;
        }
    }

    /**
     * @dev Returns number of refund confirmations of a transaction.
     * @param _escrowTransactionId Transaction ID.
     * @return count Number of confirmations.
     */
    function getRefundConfirmationCount(
        uint256 _escrowTransactionId
        )
        public
        view
        returns (uint256 count)
    {
        address to = transactions[_escrowTransactionId].to;
        address from = transactions[_escrowTransactionId].from;
        address escrowManager = transactions[_escrowTransactionId].escrowManager;

        if (refundConfirmations[_escrowTransactionId][escrowManager]) {
            count += 1;
        }
        if (refundConfirmations[_escrowTransactionId][to]) {
            count += 1;
        }
        if (refundConfirmations[_escrowTransactionId][from]) {
            count += 1;
        }
    }

    /**
     * @dev Returns number of refund confirmations of a transaction.
     * @param _escrowTransactionId Transaction ID.
     * @return transaction Number of confirmations.
     */
    function getTransaction(
        uint256 _escrowTransactionId
        )
        public
        view
        transactionExists(_escrowTransactionId)
        returns (Transaction memory)
    {
        return transactions[_escrowTransactionId];
    }

    function submitBulkEscrowTransaction(
        address[] memory _destinations,
        uint256[] memory _values,
        address _escrowManager,
        uint256[] memory _transactionIds
    ) public returns (uint256[] memory _escrowBulkTransactionIds) {
        require(_destinations.length == _values.length, "Invalid Param");
        require(_destinations.length == _transactionIds.length, "Invalid Param");

        uint256 total = _destinations.length;
        _escrowBulkTransactionIds = new uint256[](total);
        for(uint256 i = 0; i< total; i++) {
            _escrowBulkTransactionIds[i] = addTransaction(_destinations[i], _values[i], _escrowManager, _transactionIds[i]);
        }
    }

    // /**
    //  * @dev Returns total number of transactions after filers are applied.
    //  * @param _pending Include pending transactions.
    //  * @param _executed Include executed transactions.
    //  * @return count Total number of transactions after filters are applied.
    //  */
    // function getTransactionCount(bool _pending, bool _executed)
    //     public
    //     view
    //     returns (uint256 count)
    // {
    //     for (uint256 i = 0; i < transactionCount; i++)
    //         if (
    //             (_pending &&
    //                 !transactions[i].executed &&
    //                 !transactions[i].refunded) ||
    //             (_executed &&
    //                 transactions[i].executed &&
    //                 transactions[i].refunded)
    //         ) count += 1;
    // }

    // /**
    //  * @dev Returns list of transaction IDs in defined range.
    //  * @param _from Index start position of transaction array.
    //  * @param _to Index end position of transaction array.
    //  * @param _pending Include pending transactions.
    //  * @param _executed Include executed transactions.
    //  * @return escrowTransactionIds Returns array of transaction IDs.
    //  */
    // function getescrowTransactionIds(
    //     uint256 _from,
    //     uint256 _to,
    //     bool _pending,
    //     bool _executed
    // ) public view returns (uint256[] memory escrowTransactionIds) {
    //     uint256[] memory escrowTransactionIdsTemp = new uint256[](transactionCount);
    //     uint256 count = 0;
    //     uint256 i;
    //     for (i = 0; i < transactionCount; i++)
    //         if (
    //             (_pending &&
    //                 !transactions[i].executed &&
    //                 !transactions[i].refunded) ||
    //             (_executed &&
    //                 transactions[i].executed &&
    //                 transactions[i].refunded)
    //         ) {
    //             escrowTransactionIdsTemp[count] = i;
    //             count += 1;
    //         }
    //     escrowTransactionIds = new uint256[](_to - _from);
    //     for (i = _from; i < _to; i++)
    //         escrowTransactionIds[i - _from] = escrowTransactionIdsTemp[i];
    // }
}
