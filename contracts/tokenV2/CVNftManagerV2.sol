// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./CVNftV2.sol";
import "../interfaces/ICVNft.sol";
import "../interfaces/ICVConfigure.sol";

contract CVNftManagerV2 is CVNftV2, ICVNft, ReentrancyGuard, Pausable {
    /**
     * @dev Initializes Puzzle core contract.
     * @param _busd BUSD ERC20 contract address
     * @param _dev income address.
     * @param _cvCfg Puzzle strategy contract address.
     */
    constructor(
        address _busd,
        address _cvc,
        ICVCfg _cvCfg,
        address _dev
    ) public {
        _registerInterface(_INTERFACE_ID_ERC721);

        busd = ERC20(_busd);
        cvcToken = ERC20(_cvc);
        cvCfg = _cvCfg;
        incomeAddress = _dev;
    }

    /* ========== EVENTS ========== */

    // The Lotteryed event is fired when extract a new card.
    event EventLottery(uint256 indexed tokenId, uint256 geneId);

    // The Puzzled event is fired when puzzled a new card.
    event EventCompoundedBatch(uint256 indexed tokenId, uint256 geneId);

    // create an new order
    event PostOrder(
        address indexed seller,
        uint256 indexed tokenId,
        address indexed token,
        uint256 price
    );
    // cancel a selling order
    event CancelOrder(address indexed seller, uint256 indexed tokenId);
    // deal a selling order
    event DealOrder(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        address token,
        uint256 price
    );

    event BurnUpgrade(
        uint256 indexed _burnID,
        uint256 indexed _upgradeId,
        uint256 _burnPower,
        uint256 _upgradePower
    );

    /* ========== VIEWS ========== */

    /**
     * Returns all the relevant information about a specific Puzzle.
     * @param _id The token ID of the Puzzle of interest.
     */
    function getCard(uint256 _id)
        external
        view
        override
        returns (
            uint256 tokenid,
            uint256 geneid,
            uint256 roleid,
            uint256 category,
            uint256 level,
            uint256 piececount,
            uint256 piecenumber,
            uint256 power,
            uint256 worth,
            uint256 roleSequence,
            uint256 pieceSequence,
            uint256 capicaty
        )
    {
        tokenid = _id;
        geneid = genes[_id];
        require(geneid > 0, "CVNftManager: GeneID is invalid");
        Puzzle storage _puzzle = puzzles[tokenid];
        roleid = _puzzle.roleNum;
        category = _puzzle.category;
        level = _puzzle.level;
        piececount = _puzzle.pieceCount;
        piecenumber = _puzzle.pieceNumber;
        power = _puzzle.power;
        worth = _puzzle.worth;
        roleSequence = _puzzle.roleSequence;
        pieceSequence = _puzzle.pieceSequence;
        capicaty = _puzzle.capicaty;
    }

    /**
     * @dev buy blind box by cost busd
     * @param _blindNum a blind number od blind box
     */
    function buyBlind(uint256 _blindNum, uint256 _count) external {
        address msgsender = msg.sender;
        require(
            _blindNum > 0 && _blindNum < 4,
            "CVNftManager: blindnum is invalid"
        );

        require(_count > 0, "CVNftManager: count must be more than zero");

        (uint256 costvalue, bool isBusd) = cvCfg.getPrice(_blindNum);
        uint256 totalAmount = costvalue.mul(_count);

        if (isBusd) {
            totalAmount = totalAmount.mul(10**uint256(busd.decimals()));
            require(
                busd.allowance(msgsender, address(this)) >= totalAmount,
                "CVNftManager: Required BUSD fee has not been approved"
            );

            require(busd.transferFrom(msg.sender, incomeAddress, totalAmount));
        } else {
            totalAmount = totalAmount.mul(10**uint256(cvcToken.decimals()));
            require(
                cvcToken.allowance(msgsender, address(this)) >= totalAmount,
                "CVNftManager: Required CVC fee has not been approved"
            );

            require(
                cvcToken.transferFrom(msg.sender, incomeAddress, totalAmount)
            );
        }

        uint256 count = blindCounts[_blindNum][msgsender];
        blindCounts[_blindNum][msgsender] = count.add(_count);
    }

    /**
     * @dev airdrop a blind
     * @param _to address
     * @param _blindNum the number of blindbox
     * @param _blindCount airdrop count
     */
    function airdropBlind(
        address _to,
        uint256 _blindNum,
        uint256 _blindCount
    ) external {
        require(
            blindOperators[msg.sender] || msg.sender == owner(),
            "CVNftManager: msg sender is not operator or owner"
        );

        uint256 _count = blindCounts[_blindNum][_to];
        blindCounts[_blindNum][_to] = _count.add(_blindCount);
    }

    /**
     * @dev lotteryed a new card
     * @param _blindnum a blind number od blind box
     * @param _randnum a random seed
     * @return tokenID The lotteryed tokenid and geneid
     */
    function lottery(uint256 _blindnum, uint256 _randnum)
        external
        returns (uint256 tokenID, uint256 geneID)
    {
        address msgsender = msg.sender;
        require(_randnum > 0, "CVNftManager: randnum is zero");

        blindCounts[_blindnum][msgsender] = blindCounts[_blindnum][msgsender]
            .sub(1);

        //call Puzzle strategy contract
        salt = uint256(
            keccak256(abi.encodePacked(block.difficulty, now, _randnum, salt))
        );

        (
            uint256 roleNum,
            uint256 level,
            uint256 pieceCount,
            uint256 pieceNumber
        ) = cvCfg.getCards(salt, _blindnum);
        require(pieceCount > 0, "CVNftManager: the count of piece is not set");

        uint256 pieceCap = cvCfg.getPieceCap(roleNum);

        uint256 rolePieceCount = rolePieceNumCounts[roleNum][pieceNumber];

        require(
            rolePieceCount < pieceCap,
            "CVNftManager: the piece count is more than the capicaty"
        );

        uint256 power = cvCfg.powerBy(level);
        uint256 value = cvCfg.valueBy(level);

        Puzzle memory _puzzle =
            Puzzle({
                roleNum: roleNum,
                level: level,
                category: uint256(CVCategoryState.PIECE),
                pieceCount: pieceCount,
                pieceNumber: pieceNumber,
                power: power,
                worth: value,
                roleSequence: 0,
                pieceSequence: rolePieceCount,
                capicaty: pieceCap
            });

        //category is piece
        (tokenID, geneID) = _createPiece(_puzzle, msgsender);

        rolePieceNumCounts[roleNum][pieceNumber] = rolePieceCount.add(1);

        emit EventLottery(tokenID, geneID);

        return (tokenID, geneID);
    }

    function airdrop(
        address _to,
        uint256 _roleNum,
        uint256 _pieceNumber,
        uint256 _level
    ) external returns (uint256 tokenID, uint256 geneID) {
        require(
            blindOperators[msg.sender] || msg.sender == owner(),
            "CVNftManager: msg sender is not operator or owner"
        );

        uint256 pieceCount = cvCfg.getPieceCount(_roleNum);

        uint256 pieceCap = cvCfg.getPieceCap(_roleNum);

        uint256 rolePieceCount = rolePieceNumCounts[_roleNum][_pieceNumber];

        require(
            rolePieceCount < pieceCap,
            "CVNftManager: the piece count is more than the capicaty"
        );

        uint256 power = cvCfg.powerBy(_level);
        uint256 value = cvCfg.valueBy(_level);

        Puzzle memory _puzzle =
            Puzzle({
                roleNum: _roleNum,
                level: _level,
                category: uint256(CVCategoryState.PIECE),
                pieceCount: pieceCount,
                pieceNumber: _pieceNumber,
                power: power,
                worth: value,
                roleSequence: 0,
                pieceSequence: rolePieceCount,
                capicaty: pieceCap
            });

        //category is piece
        (tokenID, geneID) = _createPiece(_puzzle, _to);

        rolePieceNumCounts[_roleNum][_pieceNumber] = rolePieceCount.add(1);

        emit EventLottery(tokenID, geneID);

        return (tokenID, geneID);
    }

    /**
     * @dev multi compount Puzzle
     * @param _tokenList an array of tokenid
     * @return The tokenid and geneid of the compound Puzzle
     */
    function compoundBatch(uint256[] memory _tokenList)
        external
        returns (uint256, uint256)
    {
        require(
            (_tokenList.length % 2) == 0,
            "CVNftManager: Length is not valid"
        );

        require(
            _tokenList.length > 1,
            "CVNftManager: Length is not more than one"
        );
        Puzzle memory _puzzle0 = puzzles[_tokenList[0]];
        _burn(_tokenList[0]);

        uint256 roleNum = _puzzle0.roleNum;
        uint256 level = _puzzle0.level;
        uint256 pieceCount = _puzzle0.pieceCount;
        uint256 pieceNumber = _puzzle0.pieceNumber;

        require(
            pieceCount == _tokenList.length,
            "CVNftManager: Piece count is not equal"
        );

        Puzzle memory _puzzle =
            Puzzle({
                roleNum: roleNum,
                level: level,
                category: uint256(CVCategoryState.PICTURE),
                pieceCount: pieceCount,
                pieceNumber: 0,
                power: _puzzle0.power,
                worth: _puzzle0.worth,
                roleSequence: 0,
                pieceSequence: 0,
                capicaty: 0
            });

        for (uint256 i = 1; i < _tokenList.length; ++i) {
            uint256 _tokenID = _tokenList[i];
            Puzzle memory _puzzleitem = puzzles[_tokenID];
            require(
                roleNum == _puzzleitem.roleNum,
                "CVNftManager: The type of role is not same"
            );

            require(
                level == _puzzleitem.level,
                "CVNftManager: The level of Puzzle is not same"
            );

            require(
                _puzzleitem.pieceCount == pieceCount,
                "CVNftManager: The piece count of the Puzzle is not two"
            );

            require(
                pieceNumber != _puzzleitem.pieceNumber,
                "CVNftManager: The piece number of Puzzle piece is same"
            );

            pieceNumber = _puzzleitem.pieceNumber;

            _puzzle.power = _puzzle.power.add(_puzzleitem.power);
            _puzzle.worth = _puzzle.worth.add(_puzzleitem.worth);

            require(
                _isApprovedOrOwner(address(this), _tokenID),
                "CVNftManager: Permission is not allow"
            );
            _burn(_tokenID);
        }

        (uint256 tokenID, uint256 geneID) = _createPicture(_puzzle, msg.sender);

        emit EventCompoundedBatch(tokenID, geneID);
        return (tokenID, geneID);
    }

    function powerOf(uint256 _tokenId)
        external
        view
        override
        returns (uint256 _power)
    {
        Puzzle storage _puzzle = puzzles[_tokenId];
        return _puzzle.power;
    }

    /**
     * @dev burn NFT
     * @param _tokenID nft tokenID
     * @param  _from the token address of platform
     */
    function burn(uint256 _tokenID, address _from) external {
        require(
            ownerOf(_tokenID) == msg.sender,
            "CVNftManager: Sender is not owner"
        );

        Puzzle storage _puzzle = puzzles[_tokenID];
        uint256 amount = _puzzle.worth;

        amount = amount.mul(10**uint256(cvcToken.decimals()));

        require(
            cvcToken.allowance(_from, address(this)) >= amount,
            "CVNftManager: Required CVC fee not allowance"
        );

        require(
            cvcToken.transferFrom(_from, msg.sender, amount),
            "CVNftManager: CVC token not sent"
        );

        require(
            _isApprovedOrOwner(address(this), _tokenID),
            "CVNftManager: Permission is not allow"
        );
        _burn(_tokenID);
        delete puzzles[_tokenID];
    }

    function setCVNftCfg(ICVCfg _cvCfg) external override onlyOwner {
        cvCfg = _cvCfg;
    }

    function setIncomeAccount(address _dev) external onlyOwner {
        incomeAddress = _dev;
    }

    function order(
        uint256 _tokenid,
        bool _isCVC,
        uint256 _price
    ) external returns (bool) {
        require(
            ownerOf(_tokenid) == msg.sender,
            "CVNftManager: Sender is not owner"
        );

        require(
            orders[_tokenid].flag != 1,
            "CVNftManager: Order has already set"
        );

        require(
            _isApprovedOrOwner(address(this), _tokenid),
            "CVNftManager: NFT token is not approved"
        );

        _transfer(msg.sender, address(this), _tokenid);

        bool isCVC = cvCfg.getOrderPay();
        require(_isCVC == isCVC, "CVNftManager: NFT token pay is not same");

        OrderBook memory _book =
            OrderBook({
                user: msg.sender,
                isCVC: _isCVC,
                price: _price,
                flag: 1
            });

        orders[_tokenid] = _book;
        if (_isCVC) {
            emit PostOrder(msg.sender, _tokenid, address(cvcToken), _price);
        } else {
            emit PostOrder(msg.sender, _tokenid, address(busd), _price);
        }
        return true;
    }

    function cancelorder(uint256 _tokenid) external returns (bool) {
        OrderBook memory _order = orders[_tokenid];
        address orgin = _order.user;
        require(orgin == msg.sender, "CVNftManager: Sender is not origin");

        _transfer(address(this), orgin, _tokenid);

        require(orders[_tokenid].flag == 1, "CVNftManager: Order is not set");

        delete orders[_tokenid];
        emit CancelOrder(msg.sender, _tokenid);
        return true;
    }

    function orderBuy(uint256 _tokenid) external {
        require(_exists(_tokenid), "CVNftManager: tokeid is not exist");

        require(orders[_tokenid].flag == 1, "CVNftManager: Order is not set");

        address msgSender = msg.sender;

        OrderBook memory _book = orders[_tokenid];
        uint256 _price = _book.price;
        uint256 _platformIncome = 0;
        uint256 _remainincome = 0;
        address _to = _book.user;

        if (_book.isCVC) {
            _price = _price.mul(10**uint256(cvcToken.decimals()));

            uint256 feeRate = cvCfg.getOrderFeeRate(false);
            _platformIncome = _price.mul(feeRate).div(100);
            _remainincome = _price.sub(_platformIncome);

            require(
                cvcToken.allowance(msgSender, address(this)) >= _price,
                "CVNftManager: Required CVC fee not approve"
            );

            require(
                cvcToken.transferFrom(
                    msgSender,
                    incomeAddress,
                    _platformIncome
                ),
                "CVNftManager: CVC token not sent to income"
            );
            require(
                cvcToken.transferFrom(msgSender, _to, _remainincome),
                "CVNftManager: CVC token not sent to user"
            );
            emit DealOrder(
                msg.sender,
                _to,
                _tokenid,
                address(cvcToken),
                _price
            );
        } else {
            _price = _price.mul(10**uint256(busd.decimals()));

            uint256 feeRate = cvCfg.getOrderFeeRate(true);
            _platformIncome = _price.mul(feeRate).div(100);
            _remainincome = _price.sub(_platformIncome);
            require(
                busd.allowance(msgSender, address(this)) >= _price,
                "CVNftManager: Required BUSD fee not approve"
            );

            require(
                busd.transferFrom(msgSender, incomeAddress, _platformIncome),
                "CVNftManager: BUSD token not sent to income"
            );
            require(
                busd.transferFrom(msgSender, _to, _remainincome),
                "CVNftManager: BUSD token not sent to user"
            );
            emit DealOrder(msg.sender, _to, _tokenid, address(busd), _price);
        }

        delete orders[_tokenid];

        require(
            _isApprovedOrOwner(address(this), _tokenid),
            "CVNftManager: transfer caller is not owner nor approved"
        );
        _transfer(address(this), msgSender, _tokenid);
    }

    function setBlindOperator(address _operator, bool _allow)
        external
        onlyOwner
    {
        blindOperators[_operator] = _allow;
    }

    function addBlindCount(
        uint256 _blindNum,
        address _to,
        uint256 _count
    ) external override {
        require(
            blindOperators[msg.sender],
            "CVNftManager: msg sender is not operator"
        );

        require(
            _blindNum > 0 && _blindNum < 4,
            "CVNftManager: blind number is invalid"
        );
        require(
            _count > 0,
            "CVNftManager: blind count must be greater than zero"
        );

        blindCounts[_blindNum][_to] = blindCounts[_blindNum][_to].add(_count);
    }

    function getBlindCount(address _to) external view returns (uint256) {
        uint256 blindCap = cvCfg.getBlindCap();
        uint256 total = 0;
        for (uint256 i = 1; i <= blindCap; ++i) {
            uint256 count = blindCounts[i][_to];
            total = total.add(count);
        }

        return total;
    }

    function previewBurn(
        uint256 _burnPower,
        uint256 _upgradePower,
        bool _isSame
    )
        public
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256
        )
    {
        bool isBusd;
        uint256 factor;
        uint256 busdPrice;
        uint256 cvcPrice;

        if (_isSame) {
            (isBusd, factor, busdPrice, cvcPrice) = cvCfg.getSameBurnCfg();
        } else {
            (isBusd, factor, busdPrice, cvcPrice) = cvCfg.getDiffBurnCfg();
        }

        uint256 burnPlus = _burnPower.mul(factor).div(100);
        uint256 powerPlus = _upgradePower.add(_burnPower).add(burnPlus);
        uint256 price = 0;
        if (isBusd) {
            price = burnPlus.mul(busdPrice).mul(10**uint256(busd.decimals()));
        } else {
            price = burnPlus.mul(cvcPrice).mul(10**uint256(cvcToken.decimals()));
        }

        return (isBusd, burnPlus, powerPlus, price);
    }

    function burnPuzzle(
        uint256 _burnID,
        uint256 _upgradeID,
        bool _isSame
    ) external returns (uint256) {
        require(
            ownerOf(_burnID) == ownerOf(_upgradeID),
            "CVNftManager: Required burn the same owner"
        );
        address msgSender = msg.sender;
        Puzzle memory _burnPuzzle = puzzles[_burnID];
        Puzzle memory _upgradePuzzle = puzzles[_upgradeID];
        uint256 oldPower = _burnPuzzle.power;
        (bool isBusd, , uint256 upgradePower, uint256 price) =
            previewBurn(oldPower, _upgradePuzzle.power, _isSame);
        if (isBusd) {
            require(
                busd.allowance(msgSender, address(this)) >= price,
                "CVNftManager: Required burn BUSD not approve"
            );

            require(
                busd.transferFrom(msgSender, incomeAddress, price),
                "CVNftManager: burn BUSD token not sent to income"
            );
        } else {
            require(
                cvcToken.allowance(msgSender, address(this)) >= price,
                "CVNftManager: Required burn CVC not approve"
            );

            require(
                cvcToken.transferFrom(msgSender, incomeAddress, price),
                "CVNftManager: burn CVC token not sent to income"
            );
        }

        _burn(_burnID);
        delete puzzles[_burnID];

        _upgradePuzzle.power = upgradePower;
        _updatePuzzle(_upgradeID, _upgradePuzzle);

        emit BurnUpgrade(_burnID, _upgradeID, oldPower, upgradePower);
        return _upgradeID;
    }

    function updatePuzzle(uint256 tokenID,Puzzle memory puzzle) public {
        require(
            _isApprovedOrOwner(msg.sender,tokenID),
            "CVNftManager: update puzzle must be approved or owner"
        );

        _updatePuzzle(tokenID, puzzle);
    }

    function burnPuzzle(uint256 tokenID) public {
        require(
            _isApprovedOrOwner(msg.sender,tokenID),
            "CVNftManager: burn puzzle must be approved or owner"
        );

        _burn(tokenID);
        delete puzzles[tokenID];
    }
}
