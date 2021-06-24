// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/ICVNft.sol";
import "./CVNftManagerV2.sol";
import "./CVNftBaseV2.sol";

contract MigrateNFT is CVNftBaseV2 {
    ICVNft public oldNFTContract;
    CVNftManagerV2 public newNFTContract;

    mapping(uint256 => bool) public isMigrate; 

    event EventNFTPuzzle(address indexed to, uint256 oldTokenID, uint256 newTokenID);

    event EventBlondCount(address indexed to, uint256 count);


    constructor() public {

    }

    function setOldNFTContract(address _nft) external onlyOwner {
        oldNFTContract = ICVNft(_nft);
    }

    function setNewNFTContract(address _nft) external onlyOwner {
        newNFTContract = CVNftManagerV2(_nft);
    }

    function setMigrated(uint256 _tokenID,bool _status) external onlyOwner {
        isMigrate[_tokenID] = _status;
    }


    function getPuzzleObj(uint256 _tokenID) internal view returns (Puzzle memory,uint256) {
        (,
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
        ) = oldNFTContract.getCard(_tokenID);

        Puzzle memory _item = Puzzle({
            roleNum: roleid,
            level:level,
            category:category,
            pieceCount:piececount,
            pieceNumber:piecenumber,
            power:power,
            worth:worth,
            roleSequence:roleSequence,
            pieceSequence:pieceSequence,
            capicaty:capicaty
        });

        return (_item, geneid);
    }

    function updateBatchPuzzle(address _owner, uint256[] memory _tokenIDs) public {
        require(owner() == msg.sender, "MigrateNFT: caller is not the owner");
        
        for(uint256 i = 0; i < _tokenIDs.length;i++) {
            uint256 itemID = _tokenIDs[i];

            require(!isMigrate[itemID], "MigrateNFT: the tokenid has migrated");

            require(oldNFTContract.ownerOf(itemID) == _owner,"MigrateNFT: the owner of tokenid is not match");

            (Puzzle memory _item,uint256 geneID) = getPuzzleObj(itemID);

            (uint256 newTokenID,) = newNFTContract.migratePuzzle(_item, _owner, geneID);

            isMigrate[itemID] = true;

            emit EventNFTPuzzle(_owner,itemID,newTokenID);
        }
    }

    function updateBlindCount(address[] memory _user, uint256[] memory _counts) public onlyOwner {
        require(_user.length == _counts.length,"MigrateNFT: the length of user and blindcount is not same");

        for (uint256 i = 0; i < _user.length; i++) {
            newNFTContract.addBlindCount(1,_user[i],_counts[i]);

            emit EventBlondCount(_user[i],_counts[i]);
        }
    }

}