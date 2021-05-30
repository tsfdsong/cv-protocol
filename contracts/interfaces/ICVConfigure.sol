// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ICVCfg {
    function getCards(uint256 _seed, uint256 _blindnum)
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getPieceCount(uint256 _roleNum) external view returns (uint256);

    function getPieceCap(uint256 _rolenum) external view returns (uint256);

    function powerBy(uint256 _level) external view returns (uint256 power);

    function valueBy(uint256 _level) external view returns (uint256 value);

    function getPrice(uint256 _blindnum) external view returns (uint256, bool);

    function getPowerOverflow() external view returns (uint256);

    function getValueOverflow() external view returns (uint256);

    function getOrderFeeRate(bool _isBusd) external view returns (uint256);

    function getOrderPay() external view returns (bool);

    function getBlindCap() external view returns (uint256);

    function getPowerX() external view returns (uint256);

    function getPowerY() external view returns (uint256);

    function getSameBurnCfg()
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256
        );

    function getDiffBurnCfg()
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256
        );
}
