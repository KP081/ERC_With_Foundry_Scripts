// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MyERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    error WrongAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        name = _name;
        decimals = _decimals;
        symbol = _symbol;

        _mint(msg.sender , _initialSupply);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        if (to == address(0)) revert WrongAddress();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        if (spender == address(0)) revert WrongAddress();

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        if (from == address(0) || to == address(0)) revert WrongAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        if (allowance[from][msg.sender] < amount)
            revert InsufficientAllowance();

        allowance[from][msg.sender] -= amount;

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public returns (bool) {
        if (spender == address(0)) revert WrongAddress();

        allowance[msg.sender][spender] += addedValue;

        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subValue
    ) public returns (bool) {
        if(spender == address(0)) revert WrongAddress();

        uint256 currentAllowance = allowance[msg.sender][spender];
        if(currentAllowance < subValue) revert InsufficientAllowance();

        allowance[msg.sender][spender] = currentAllowance - subValue;

        emit Approval(msg.sender , spender , allowance[msg.sender][spender]);
        return true;
    }

    function _mint(address account , uint256 amount) internal {
        if (account == address(0)) revert WrongAddress();

        totalSupply += amount;
        balanceOf[account] += amount;

        emit Transfer(address(0) , account , amount);
    }

    function _burn(address account , uint256 amount) internal {
        if (account == address(0)) revert WrongAddress();
        if (balanceOf[account] < amount) revert InsufficientBalance();

        balanceOf[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account , address(0) , amount);
    }

    function mint(address to , uint256 amount) public {
        _mint(to , amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender , amount);
    }

    function burnFrom(address account , uint256 amount) public {
        if (allowance[account][msg.sender] < amount) revert InsufficientAllowance();

        allowance[account][msg.sender] -= amount;
        _burn(account , amount);
    }
}
