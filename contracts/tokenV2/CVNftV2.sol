// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CVNftBaseV2.sol";

contract CVNftV2 is CVNftBaseV2, ERC721("CV NFT", "CV") {
    using SafeMath for uint256;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 internal constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /**
     * @dev Magic value of a smart contract that can recieve NFT.
     * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
     */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    /* ========== VIEWS ========== */

    /* ========== OWNER MUTATIVE FUNCTION ========== */

    /**
     * @dev Allow contract owner to create Puzzle
     * geneID: || 4 Bytes RoleNum | 1 Byte Level | 1 Byte Category | 1 Byte PieceCount | 1 Byte PieceNumber
     */
    function _createPiece(Puzzle memory _puzzle, address _owner)
        internal
        returns (uint256, uint256)
    {
        tokenIDs.increment();
        uint256 tokenID = tokenIDs.current();
        puzzles[tokenID] = _puzzle;

        _mint(_owner, tokenID);

        uint256 geneRole = uint256((_puzzle.roleNum & uint256(0xffff)) << 32);
        uint256 geneLevel = uint256((_puzzle.level & uint256(0xff)) << 24);
        uint256 geneCategory =
            uint256((_puzzle.category & uint256(0xffff)) << 16);
        uint256 geneCount = uint256((_puzzle.pieceCount & uint256(0xff)) << 8);

        uint256 geneNumber = uint256(_puzzle.pieceNumber & uint256(0xff));

        uint256 geneID =
            geneRole.add(geneLevel).add(geneCategory).add(geneCount).add(
                geneNumber
            );
        genes[tokenID] = geneID;
        return (tokenID, geneID);
    }

    /**
     * @dev Allow contract owner to create Puzzle
     * geneID: || 4 Bytes RoleNum | 1 Byte Level | 1 Byte Category | 1 Byte PieceCount | 1 Byte PieceNumber
     */
    function _createPicture(Puzzle memory _puzzle, address _owner)
        internal
        returns (uint256, uint256)
    {
        _puzzle.power = _puzzle.power.mul(cvCfg.getPowerOverflow()).div(10);
        _puzzle.worth = _puzzle.worth.mul(cvCfg.getValueOverflow()).div(10);

        uint256 _combinedSequence = roleCounts[_puzzle.roleNum][_puzzle.level];
        _puzzle.roleSequence = _combinedSequence;

        tokenIDs.increment();
        uint256 tokenID = tokenIDs.current();
        puzzles[tokenID] = _puzzle;

        _mint(_owner, tokenID);

        roleCounts[_puzzle.roleNum][_puzzle.level] = _combinedSequence.add(1);

        uint256 geneRole = uint256((_puzzle.roleNum & uint256(0xffff)) << 32);
        uint256 geneLevel = uint256((_puzzle.level & uint256(0xff)) << 24);
        uint256 geneCategory =
            uint256((_puzzle.category & uint256(0xffff)) << 16);
        uint256 geneCount = uint256((_puzzle.pieceCount & uint256(0xff)) << 8);

        uint256 geneNumber = uint256(_puzzle.pieceNumber & uint256(0xff));

        uint256 geneID =
            geneRole.add(geneLevel).add(geneCategory).add(geneCount).add(
                geneNumber
            );

        genes[tokenID] = geneID;

        return (tokenID, geneID);
    }

    /**
     * @dev Allow contract owner to update Puzzle
     */
    function _updatePuzzle(uint256 _tokenID, Puzzle memory _puzzle) internal {
        puzzles[_tokenID] = _puzzle;
    }

    function _migratePuzzle(Puzzle memory _puzzle, address _owner,uint256  geneID) internal returns (uint256,uint256) {
        tokenIDs.increment();
        uint256 tokenID = tokenIDs.current();
        puzzles[tokenID] = _puzzle;

        _mint(_owner, tokenID);

        if (_puzzle.category == uint256(CVCategoryState.PICTURE)) {
            uint256 _combinedSequence = roleCounts[_puzzle.roleNum][_puzzle.level];
            roleCounts[_puzzle.roleNum][_puzzle.level] = _combinedSequence.add(1);
        }else {
            uint256 rolePieceCount = rolePieceNumCounts[_puzzle.roleNum][_puzzle.pieceNumber];
            rolePieceNumCounts[_puzzle.roleNum][_puzzle.pieceNumber] = rolePieceCount.add(1);
        }

        genes[tokenID] = geneID;

        return (tokenID, geneID);
    }
}
