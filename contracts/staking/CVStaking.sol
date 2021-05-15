// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ICVNft.sol";

contract CVStaking is Ownable {
    using SafeMath for uint256;

    // constants
    bytes4 private constant TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    // events
    event Stake(
        address indexed onwer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 power
    );

    event Redeem(
        address indexed onwer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 power
    );

    event ClaimBox(
        address indexed to,
        uint256 indexed box,
        uint256 value,
        uint256 _boxPrice
    );
    event ClaimCVC(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Settle(
        uint256 indexed index,
        uint256 fromBlockNumber,
        uint256 toBlockNumber,
        uint256 totalPower
    );

    // configs
    address public nftAddress;
    address public cvcAddress;
    address public platformAccountAddress;

    // box num => box price
    mapping(uint256 => uint256) boxesPrice;

    uint256 public boxIncomePerBlock;
    uint256 public cvcIncomePerBlock;

    uint256 public clearInvalidUsersThreshold = 30;
    uint256 public settleAllUsersInterval = 1 minutes;
    uint256 public usersGroupLimit = 100;

    constructor(address _nftAddress) public {
        nftAddress = _nftAddress;
    }

    // vars
    struct SettleVars {
        uint256 userTotalPower;
        uint256 totalPower;
        uint256 totalBoxIncome;
        uint256 totalCVCIncome;
        uint256 lastBlockNumber;
        address user;
    }
    uint256 public totalPower;
    uint256 public usersGroupIndex = 100;

    mapping(address => uint256) usersTotalPower;

    // nftAddress => userAddress => tokenId => staked
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private stakings;

    mapping(address => bool) private stakingUsers;

    mapping(address => uint256) usersBoxScoreBalance;
    mapping(address => uint256) usersCVCBalance;

    mapping(uint256 => address[]) usersGroup;
    mapping(uint256 => uint256) lastSettleUsersIncomeBlockNumberGroup;
    mapping(address => uint256) lastSettleUsersCVCIncomeBlockNumber;

    modifier checkNftAddress(address _nftAddress) {
        require(nftAddress != address(0), "No nft address was set");
        require(_nftAddress == nftAddress, "Unknown nft address");
        _;
    }

    modifier checkTokeIdOwner(address _nftAddress, uint256 _tokenId) {
        require(
            ICVNft(_nftAddress).ownerOf(_tokenId) == msg.sender,
            "Not owner of tokenId"
        );
        _;
    }

    // settings
    function setBoxIncomePerBlock(uint256 _boxIncomePerBlock)
        external
        onlyOwner
    {
        boxIncomePerBlock = _boxIncomePerBlock;
    }

    function setCvcIncomePerBlock(uint256 _cvcIncomePerBlock)
        external
        onlyOwner
    {
        cvcIncomePerBlock = _cvcIncomePerBlock;
    }

    function setBoxPrice(uint256 _box, uint256 _boxPrice) external onlyOwner {
        require(_boxPrice > 0, "Box price must be greater than zero");
        boxesPrice[_box] = _boxPrice;
    }

    function setPlatformAccountAddress(address _platformAccountAddress)
        external
        onlyOwner
    {
        require(
            _platformAccountAddress != address(0),
            "Platform address cannot be zero address"
        );
        platformAccountAddress = _platformAccountAddress;
    }

    function setCVCAddress(address _cvcAddress) external onlyOwner {
        require(
            _cvcAddress != address(0),
            "CVC address cannot be zero address"
        );
        cvcAddress = _cvcAddress;
    }

    // read
    function boxPriceOf(uint256 _box)
        external
        view
        returns (uint256 _boxPrice)
    {
        _boxPrice = boxesPrice[_box];
    }

    function totalPowerOf(address _user)
        external
        view
        returns (uint256 _totalPower)
    {
        _totalPower = usersTotalPower[_user];
    }

    function boxBalanceOf(address _user)
        external
        view
        returns (uint256 _balance)
    {
        _balance = usersBoxScoreBalance[_user];
    }

    function cvcBalanceOf(address _user)
        external
        view
        returns (uint256 _balance)
    {
        if (totalPower == 0) {
            _balance = 0;
        } else {
            _balance = usersTotalPower[_user]
                .mul(
                cvcIncomePerBlock.mul(
                    block.number.sub(lastSettleUsersCVCIncomeBlockNumber[_user])
                )
            )
                .div(totalPower);
        }
    }

    /**
     * @dev call nft contract to tranfer tokenId
     * @param _from nft tokenId source owner
     * @param _to nft tokenId target owner
     * @param _tokenId _tokenId
     */
    function _transferNft(
        address _nftAddress,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal returns (bool _result) {
        (bool success, bytes memory data) =
            _nftAddress.call(
                abi.encodeWithSelector(
                    TRANSFER_FROM_SELECTOR,
                    _from,
                    _to,
                    _tokenId
                )
            );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer nft failed"
        );
        _result = true;
    }

    /**
     * @dev call token contract to tranfer value
     * @param _from token value source owner
     * @param _to token value target owner
     * @param _value _value
     */
    function _transferToken(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool _result) {
        (bool success, bytes memory data) =
            _tokenAddress.call(
                abi.encodeWithSelector(
                    TRANSFER_FROM_SELECTOR,
                    _from,
                    _to,
                    _value
                )
            );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer token failed"
        );
        _result = true;
    }

    function stake(address _nftAddress, uint256 _tokenId)
        external
        checkNftAddress(_nftAddress)
        checkTokeIdOwner(_nftAddress, _tokenId)
    {
        address _user = msg.sender;
        IERC721 _nft = IERC721(_nftAddress);
        require(
            _nft.getApproved(_tokenId) == address(this) ||
                _nft.isApprovedForAll(_user, address(this)),
            "NFT was not approved for this staking address"
        );
        bool success =
            _transferNft(_nftAddress, _user, address(this), _tokenId);
        require(success, "Stake nft failed");

        uint256 _power = ICVNft(_nftAddress).powerOf(_tokenId);
        uint256 _lastPower = usersTotalPower[_user];
        if (!stakingUsers[_user]) {
            uint256 _usersGroupIndex = usersGroupIndex;
            uint256 _usersGroupLimit = usersGroupLimit;
            address[] storage _users = usersGroup[_usersGroupIndex];
            if (_users.length >= _usersGroupLimit) {
                _usersGroupIndex = _usersGroupIndex.add(_usersGroupLimit);
                _users = usersGroup[_usersGroupIndex];
            }
            _users.push(_user);
            usersGroupIndex = _usersGroupIndex;
            if (lastSettleUsersIncomeBlockNumberGroup[_usersGroupIndex] == 0) {
                lastSettleUsersIncomeBlockNumberGroup[_usersGroupIndex] = block
                    .number;
            }
            if (lastSettleUsersCVCIncomeBlockNumber[_user] == 0) {
                lastSettleUsersCVCIncomeBlockNumber[_user] = block.number;
            }
            stakingUsers[_user] = true;
        }

        totalPower = totalPower.add(_power);
        usersTotalPower[_user] = _lastPower.add(_power);
        stakings[_nftAddress][_user][_tokenId] = true;

        emit Stake(_user, _nftAddress, _tokenId, _power);
    }

    function redeem(address _nftAddress, uint256 _tokenId)
        external
        checkNftAddress(_nftAddress)
    {
        address _user = msg.sender;
        require(
            stakings[_nftAddress][_user][_tokenId],
            "Token id was not staked"
        );
        bool success =
            _transferNft(_nftAddress, address(this), _user, _tokenId);
        require(success, "Redeem nft failed");

        _settleCVCIncome();

        uint256 _power = ICVNft(_nftAddress).powerOf(_tokenId);
        totalPower = totalPower.sub(_power);
        uint256 _userTotalPower = usersTotalPower[_user].sub(_power);
        usersTotalPower[_user] = _userTotalPower;
        delete stakings[_nftAddress][_user][_tokenId];

        emit Redeem(_user, _nftAddress, _tokenId, _power);
    }

    function _settleCVCIncome() internal {
        address _user = msg.sender;
        uint256 _value =
            usersTotalPower[_user]
                .mul(
                cvcIncomePerBlock.mul(
                    block.number.sub(lastSettleUsersCVCIncomeBlockNumber[_user])
                )
            )
                .div(totalPower);

        address _cvcAddress = cvcAddress;
        require(_cvcAddress != address(0), "No cvc address was set");
        address _platformAccountAddress = platformAccountAddress;
        require(
            _platformAccountAddress != address(0),
            "No platform account address was set"
        );
        require(
            IERC20(_cvcAddress).allowance(
                _platformAccountAddress,
                address(this)
            ) >= _value,
            "CVC allowance was not enough"
        );
        bool _result =
            _transferToken(_cvcAddress, _platformAccountAddress, _user, _value);
        require(_result, "Claim cvc failed");
        lastSettleUsersCVCIncomeBlockNumber[_user] = block.number;
        emit ClaimCVC(_cvcAddress, _platformAccountAddress, _user, _value);
    }

    function _settleIncome(SettleVars memory vars) internal {
        uint256 _boxIncome =
            vars.totalBoxIncome.mul(vars.userTotalPower).div(vars.totalPower);
        usersBoxScoreBalance[vars.user] = usersBoxScoreBalance[vars.user].add(
            _boxIncome
        );
    }

    /**
     * @dev settle All Users Income per 24 hours
     */
    function settleAllUsersIncome(uint256 _index) external onlyOwner {
        uint256 _totalPower = totalPower;
        require(_totalPower > 0, "No staking data");
        SettleVars memory vars;
        vars.totalPower = _totalPower;
        vars.lastBlockNumber = lastSettleUsersIncomeBlockNumberGroup[_index];
        uint256 _deltaBlockNumber = block.number.sub(vars.lastBlockNumber);
        vars.totalBoxIncome = boxIncomePerBlock.mul(_deltaBlockNumber);
        vars.totalCVCIncome = cvcIncomePerBlock.mul(_deltaBlockNumber);
        address[] memory _users = usersGroup[_index];
        for (uint256 _i = 0; _i < _users.length; _i = _i.add(1)) {
            vars.user = _users[_i];
            if (vars.user == address(0)) {
                continue;
            }
            vars.userTotalPower = usersTotalPower[vars.user];
            if (vars.userTotalPower > 0) {
                _settleIncome(vars);
            }
        }
        lastSettleUsersIncomeBlockNumberGroup[_index] = block.number;
        emit Settle(
            _index,
            vars.lastBlockNumber,
            block.number,
            vars.totalPower
        );
    }

    function claimBox(uint256 _box, uint256 _value) external {
        uint256 _boxPrice = boxesPrice[_box];
        require(_boxPrice > 0, "This box was not set");
        address _user = msg.sender;
        uint256 _balance = usersBoxScoreBalance[_user];
        uint256 _neededScore = _boxPrice.mul(_value);
        usersBoxScoreBalance[_user] = _balance.sub(
            _neededScore,
            "Caller has not enough box score balance"
        );
        ICVNft(nftAddress).addBlindCount(_box, _user, _value);
        emit ClaimBox(_user, _box, _value, _boxPrice);
    }

    function claimCVC() external {
        _settleCVCIncome();
    }
}
