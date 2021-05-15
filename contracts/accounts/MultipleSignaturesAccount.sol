// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultipleSignaturesAccount is Ownable {
    using SafeMath for uint256;

    // constants
    bytes4 private constant TRANSFER_SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    string public name;

    // the operation will be effected which was confirm with as least <confirmCountThreshold> admins
    uint256 public confirmCountThreshold = 1;

    constructor(string memory _name) public {
        name = _name;
    }

    struct AdminData {
        bool isSet;
        uint256 index;
    }

    mapping(address => AdminData) public admins;
    address[] public keyAdmins;

    event Widthdraw(
        address indexed operator,
        address indexed token,
        address indexed to,
        uint256 _value
    );

    address public applyWithdrawApplicant;
    address[] public applyWithdrawComfirmedAdmins;
    mapping(address => bool) public applyWithdrawComfirmedAdminsStatus;
    address public applyWithdrawToken;
    address public applyWithdrawTo;
    uint256 public applyWithdrawValue;
    uint256 public applyWithdrawConfirmCount;

    modifier isNotZeroAddress(address _address) {
        require(_address != address(0), "Address could not be zero address");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender].isSet, "Caller is not the admin");
        _;
    }

    // settings
    function setName(string memory _name) external onlyOwner {
        name = _name;
    }

    function addAdmin(address _admin)
        external
        onlyOwner
        isNotZeroAddress(_admin)
    {
        require(!admins[_admin].isSet, "Admin has already set");

        AdminData memory _item =
            AdminData({isSet: true, index: keyAdmins.length});
        admins[_admin] = _item;

        keyAdmins.push(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(admins[_admin].isSet, "Admin has not set");
        uint256 index = admins[_admin].index;
        keyAdmins[index] = keyAdmins[keyAdmins.length - 1];

        delete keyAdmins[keyAdmins.length - 1];
        keyAdmins.pop();
        delete admins[_admin];
    }

    function getAdmin() external view returns (address[] memory) {
        return keyAdmins;
    }

    function isAdmin(address _user) external view returns (bool _isAdmin) {
        _isAdmin = admins[_user].isSet;
    }

    function setConfirmCountThreshold(uint256 _confirmCountThreshold)
        external
        onlyOwner
    {
        require(
            _confirmCountThreshold > 0,
            "Confirm count threshold can not be zero"
        );
        confirmCountThreshold = _confirmCountThreshold;
    }

    function getConfirmCountThreshold() external view returns (uint256) {
        return confirmCountThreshold;
    }

    function balanceOf(address _token)
        external
        view
        returns (uint256 _balance)
    {
        _balance = IERC20(_token).balanceOf(address(this));
    }

    function _transfer(
        address _token,
        address _to,
        uint256 _value
    ) internal returns (bool _result) {
        (bool success, bytes memory data) =
            _token.call(abi.encodeWithSelector(TRANSFER_SELECTOR, _to, _value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer token failed"
        );
        _result = true;
    }

    function applyWithdraw(
        address _token,
        address _to,
        uint256 _value
    ) external onlyAdmin {
        require(
            applyWithdrawApplicant == address(0),
            "There was a applying which was confirmed yet"
        );
        require(_value > 0, "Can not withdraw zero value");
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        require(
            _balance >= _value,
            "There was not enough balance of this accout"
        );
        if (confirmCountThreshold == 1) {
            bool _result = _transfer(_token, _to, _value);
            require(_result, "Withdraw directly failed");
            emit Widthdraw(msg.sender, _token, _to, _value);
        } else {
            address _user = msg.sender;
            applyWithdrawApplicant = _user;
            applyWithdrawToken = _token;
            applyWithdrawTo = _to;
            applyWithdrawValue = _value;
            applyWithdrawComfirmedAdmins.push(_user);
            applyWithdrawComfirmedAdminsStatus[_user] = true;
        }
    }

    function getApplyingInfo(address _admin)
        external
        view
        returns (
            bool _hasApplying,
            address _applyWithdrawApplicant,
            address _applyWithdrawToken,
            address _applyWithdrawTo,
            uint256 _applyWithdrawValue,
            bool _doConfirm,
            bool _isAdmin
        )
    {
        _hasApplying = applyWithdrawApplicant != address(0);
        _applyWithdrawApplicant = applyWithdrawApplicant;
        _applyWithdrawToken = applyWithdrawToken;
        _applyWithdrawTo = applyWithdrawTo;
        _applyWithdrawValue = applyWithdrawValue;
        _doConfirm = applyWithdrawComfirmedAdminsStatus[_admin];
        _isAdmin = admins[_admin].isSet;
    }

    function confirmApplyingWithdraw() external onlyAdmin {
        address _user = msg.sender;
        require(
            !applyWithdrawComfirmedAdminsStatus[_user],
            "Can not comfirm repeatedly"
        );
        applyWithdrawComfirmedAdmins.push(_user);
        address[] memory _applyWithdrawComfirmedAdmins =
            applyWithdrawComfirmedAdmins;
        uint256 _len = _applyWithdrawComfirmedAdmins.length;
        if (_len >= confirmCountThreshold) {
            bool _result =
                _transfer(
                    applyWithdrawToken,
                    applyWithdrawTo,
                    applyWithdrawValue
                );
            require(_result, "Confirm applying withdraw failed");
            emit Widthdraw(
                applyWithdrawApplicant,
                applyWithdrawToken,
                applyWithdrawTo,
                applyWithdrawValue
            );
            delete applyWithdrawApplicant;
            delete applyWithdrawToken;
            delete applyWithdrawTo;
            delete applyWithdrawValue;
            for (uint256 _i; _i < _len; _i = _i.add(1)) {
                address _admin = _applyWithdrawComfirmedAdmins[_i];
                delete applyWithdrawComfirmedAdminsStatus[_admin];
            }
            delete applyWithdrawComfirmedAdmins;
        }
    }

    function withdrawDirectly(
        address _token,
        address _to,
        uint256 _value
    ) external onlyOwner isNotZeroAddress(_token) {
        require(_value > 0, "Can not withdraw zero value");
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        require(
            _balance >= _value,
            "There was not enough balance of this account"
        );
        bool _result = _transfer(_token, _to, _value);
        require(_result, "Withdraw directly failed");
        emit Widthdraw(msg.sender, _token, _to, _value);
    }

    function approve(
        address _token,
        address _spender,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).approve(_spender, _amount);
    }
}
