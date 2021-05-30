// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../interfaces/ICVConfigure.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CVCfg is ICVCfg, Ownable {
    using SafeMath for uint256;

    enum CVCfgLevelState {COMMON, GOLD, DIAMOND, RESERVED}

    struct BlindBox {
        uint256 price;
        bool isBusd;
        //sequence
        uint256 startIndex;
        uint256 endIndex;
        //level
        uint256 levelFirst;
        uint256 levelSecond;
        uint256 levelThird;
        //init or else
        bool isSet;
    }

    struct PieceConst {
        uint256 pieceCount;
        uint256 pieceCapicaty;
        bool isSet;
    }
    //nft order
    bool public isCVCOrder;
    uint256 public feeRateBusd;
    uint256 public feeRateCVC;

    uint256 public energyCommon;
    uint256 public energyGold;
    uint256 public energyDiamond;

    uint256 public overflowPower;

    uint256 public valueCommon;
    uint256 public valueGold;
    uint256 public valueDiamond;

    uint256 public overflowValue;

    //the number of blind box
    mapping(uint256 => BlindBox) public boxs;
    uint256 public boxCount;

    //upgrade power
    uint256 public powerX; //index
    uint256 public powerY; //the count of cvc

    /**
     * @dev An mapping containing the roleid and struct of PieceConst.
     */
    mapping(uint256 => PieceConst) public rolePieces;

    /**
     * @dev An mapping containing the piececount and PieceNumber.
     */
    struct PieceNumber {
        uint256 number;
        bool isSet;
    }
    mapping(uint256 => PieceNumber) public pieceNumber;

    //burm power
    struct BurnPower {
        bool isBusd;
        uint256 burnFactor;
        uint256 busdPowerPrice;
        uint256 cvcPowerPrice;
    }

    BurnPower public sameBurnCfg;
    BurnPower public diffBurnCfg;

    constructor() public {
        BlindBox memory _blind =
            BlindBox({
                price: 50,
                isBusd: true,
                startIndex: 1,
                endIndex: 100,
                levelFirst: 82,
                levelSecond: 16,
                levelThird: 2,
                isSet: true
            });
        boxs[1] = _blind;
        boxCount = boxCount.add(1);

        energyCommon = uint256(100);
        energyGold = uint256(1000);
        energyDiamond = uint256(8000);
        overflowPower = uint256(12);

        valueCommon = uint256(10);
        valueGold = uint256(30);
        valueDiamond = uint256(100);
        overflowValue = uint256(12);

        isCVCOrder = true;
        feeRateBusd = uint256(10);
        feeRateCVC = uint256(10);

        powerX = 350;
        powerY = 1;

        sameBurnCfg = BurnPower({
            isBusd: true,
            burnFactor: 120,
            busdPowerPrice: 17,
            cvcPowerPrice: 83
        });

        diffBurnCfg = BurnPower({
            isBusd: true,
            burnFactor: 110,
            busdPowerPrice: 2517,
            cvcPowerPrice: 125
        });
    }

    function setBlind(
        uint256 _number,
        uint256 _price,
        bool _isBusd,
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _levelFirst,
        uint256 _levelSecond,
        uint256 _levelThird
    ) external onlyOwner {
        require(
            _number > 0 && _number < 4,
            "CVConfigure: BlindNumber is invalid"
        );

        boxCount = boxCount.add(1);

        uint256 plus = _levelFirst.add(_levelSecond).add(_levelThird);
        require(plus <= 100, "CVConfigure: Set level is invalid");

        BlindBox memory _blind =
            BlindBox({
                price: _price,
                isBusd: _isBusd,
                startIndex: _startIndex,
                endIndex: _endIndex,
                levelFirst: _levelFirst,
                levelSecond: _levelSecond,
                levelThird: _levelThird,
                isSet: true
            });
        boxs[_number] = _blind;
    }

    function setPrice(
        uint256 _number,
        uint256 _price,
        bool _isbusd
    ) external onlyOwner {
        require(
            _number > 0 && _number < 4,
            "CVConfigure: BlindNumber is invalid"
        );
        require(boxs[_number].isSet, "CVConfigure: Blind box is not set");

        boxs[_number].price = _price;
        boxs[_number].isBusd = _isbusd;
    }

    function setIndex(
        uint256 _number,
        uint256 _start,
        uint256 _end
    ) external onlyOwner {
        require(_number > 0 && _number < 4);
        require(boxs[_number].isSet);

        boxs[_number].startIndex = _start;
        boxs[_number].endIndex = _end;
    }

    function setLevelRange(
        uint256 _number,
        uint256 _first,
        uint256 _second,
        uint256 _third
    ) external onlyOwner {
        require(
            _number > 0 && _number < 4,
            "CVConfigure: BlindNumber is invalid"
        );
        require(boxs[_number].isSet, "CVConfigure: Blind box is not set");

        uint256 plus = _first.add(_second).add(_third);
        require(plus <= 100);

        boxs[_number].levelFirst = _first;
        boxs[_number].levelSecond = _second;
        boxs[_number].levelThird = _third;
    }

    function setPower(
        uint256 _common,
        uint256 _gold,
        uint256 _diamond,
        uint256 _overflow
    ) external onlyOwner {
        energyCommon = _common;
        energyGold = _gold;
        energyDiamond = _diamond;
        overflowPower = _overflow;
    }

    function setValue(
        uint256 _common,
        uint256 _gold,
        uint256 _diamond,
        uint256 _overflow
    ) external onlyOwner {
        valueCommon = _common;
        valueGold = _gold;
        valueDiamond = _diamond;
        overflowValue = _overflow;
    }

    function setPieceCountAndCapicaty(
        uint256[] memory _rolenums,
        uint256[] memory _piecenums,
        uint256[] memory _piececap
    ) external onlyOwner {
        require(
            _rolenums.length == _piecenums.length,
            "CVConfigure: Length of count is not equal"
        );

        require(
            _rolenums.length == _piececap.length,
            "CVConfigure: Length of cap is not equal"
        );

        for (uint256 i = 0; i < _rolenums.length; ++i) {
            uint256 rolenum = _rolenums[i];
            uint256 pieceCnt = _piecenums[i];

            PieceConst memory _pieceConst =
                PieceConst({
                    pieceCount: pieceCnt,
                    pieceCapicaty: _piececap[i],
                    isSet: true
                });
            rolePieces[rolenum] = _pieceConst;

            if (!pieceNumber[pieceCnt].isSet) {
                PieceNumber memory _pieceNum =
                    PieceNumber({number: 0, isSet: true});
                pieceNumber[pieceCnt] = _pieceNum;
            }
        }
    }

    function setOrderFee(bool _isCVC, uint256 _feeRate) external onlyOwner {
        if (_isCVC) {
            isCVCOrder = true;
            feeRateCVC = _feeRate;
        } else {
            isCVCOrder = false;
            feeRateBusd = _feeRate;
        }
    }

    function setPowerX(uint256 _pox) external onlyOwner {
        powerX = _pox;
    }

    function setPowerY(uint256 _poy) external onlyOwner {
        powerY = _poy;
    }

    /**
     * @dev get cards attribute.
     * @param _seed random seed.
     * @param _blindnum the blind number of blind box.
     * @return rolenum the number of card.
     * @return level the level of card, 0: common; 1: gold; 2: diamond.
     * @return piece count of card
     * @return piece capicaty of card
     */
    function getCards(uint256 _seed, uint256 _blindnum)
        external
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(
            _blindnum > 0 && _blindnum < 4,
            "CVConfigure: BlindNumber is invalid"
        );

        BlindBox memory _box = boxs[_blindnum];

        //calculate role number by random
        uint256 distance = _box.endIndex.sub(_box.startIndex).add(1);
        uint256 roleNum = _box.startIndex.add(_seed % distance);
        if (_box.endIndex == _box.startIndex) {
            roleNum = _box.startIndex;
        }

        //calculate category by random
        uint256 modNumber = _seed % 100;

        //calculate level by random
        uint256 level = 0;
        if (modNumber <= _box.levelFirst) {
            level = uint256(CVCfgLevelState.COMMON); //common
        } else if (modNumber <= _box.levelFirst.add(_box.levelSecond)) {
            level = uint256(CVCfgLevelState.GOLD); //gold
        } else if (
            modNumber <=
            _box.levelFirst.add(_box.levelSecond).add(_box.levelThird)
        ) {
            level = uint256(CVCfgLevelState.DIAMOND); //diamond
        } else {
            level = uint256(CVCfgLevelState.RESERVED); //reserve
        }

        if (!rolePieces[roleNum].isSet) {
            return (0, 0, 0, 0);
        }

        uint256 pieceCount = rolePieces[roleNum].pieceCount;
        PieceNumber storage _pieceNum = pieceNumber[pieceCount];
        require(_pieceNum.isSet, "CVConfigure: number of piece is not set");

        uint256 pieceNum = _pieceNum.number;
        uint256 nextPieceNum = uint256(pieceNum.add(1) % pieceCount);
        _pieceNum.number = nextPieceNum;

        return (roleNum, level, pieceCount, pieceNum);
    }

    function getPieceCap(uint256 _roleNum)
        external
        view
        override
        returns (uint256)
    {
        require(
            rolePieces[_roleNum].isSet,
            "CVConfigure: piece of role is not set"
        );
        return rolePieces[_roleNum].pieceCapicaty;
    }

    function getPieceCount(uint256 _roleNum)
        external
        view
        override
        returns (uint256)
    {
        require(
            rolePieces[_roleNum].isSet,
            "CVConfigure: piece of role is not set"
        );
        return rolePieces[_roleNum].pieceCount;
    }

    function powerBy(uint256 _level)
        external
        view
        override
        returns (uint256 power)
    {
        if (_level == uint256(CVCfgLevelState.COMMON)) {
            power = energyCommon;
        } else if (_level == uint256(CVCfgLevelState.GOLD)) {
            power = energyGold;
        } else {
            power = energyDiamond;
        }
    }

    function valueBy(uint256 _level)
        external
        view
        override
        returns (uint256 value)
    {
        if (_level == uint256(CVCfgLevelState.COMMON)) {
            value = valueCommon;
        } else if (_level == uint256(CVCfgLevelState.GOLD)) {
            value = valueGold;
        } else {
            value = valueDiamond;
        }
    }

    function getPrice(uint256 _blindNum)
        external
        view
        override
        returns (uint256, bool)
    {
        require(
            _blindNum > 0 && _blindNum < 4,
            "CVConfigure: BlindNumber is invalid"
        );
        require(boxs[_blindNum].isSet, "CVConfigure: Blind box is not set");

        return (boxs[_blindNum].price, boxs[_blindNum].isBusd);
    }

    function getPowerOverflow() external view override returns (uint256) {
        return overflowPower;
    }

    function getValueOverflow() external view override returns (uint256) {
        return overflowValue;
    }

    function getOrderFeeRate(bool _isBusd)
        external
        view
        override
        returns (uint256)
    {
        if (_isBusd) {
            return feeRateBusd;
        } else {
            return feeRateCVC;
        }
    }

    function getOrderPay() external view override returns (bool) {
        return isCVCOrder;
    }

    function getBlindCap() external view override returns (uint256) {
        return boxCount;
    }

    function getPowerX() external view override returns (uint256) {
        return powerX;
    }

    function getPowerY() external view override returns (uint256) {
        return powerY;
    }

    function setSameBurnCfg(
        bool _isBusd,
        uint256 _factor,
        uint256 _busd,
        uint256 _cvc
    ) external onlyOwner {
        sameBurnCfg.isBusd = _isBusd;
        sameBurnCfg.burnFactor = _factor;
        sameBurnCfg.busdPowerPrice = _busd;
        sameBurmCfg.cvcPowerPrice = _cvc;
    }

    function setDiffBurnCfg(
        bool _isBusd,
        uint256 _factor,
        uint256 _busd,
        uint256 _cvc
    ) external onlyOwner {
        diffBurnCfg.isBusd = _isBusd;
        diffBurnCfg.burnFactor = _factor;
        diffBurnCfg.busdPowerPrice = _busd;
        diffBurnCfg.cvcPowerPrice = _cvc;
    }

    function getSameBurnCfg()
        external
        view
        override
        returns (
            bool,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            sameBurnCfg.isBusd,
            sameBurnCfg.burnFactor,
            sameBurnCfg.busdPowerPrice,
            sameBurmCfg.cvcPowerPrice
        );
    }

    function getDiffBurnCfg()
        external
        view
        override
        returns (
            bool,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            diffBurnCfg.isBusd,
            diffBurnCfg.burnFactor,
            diffBurnCfg.busdPowerPrice,
            diffBurnCfg.cvcPowerPrice
        );
    }
}
