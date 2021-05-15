## 质押合约Staking.sol

### 方法说明

读方法

##### 盲盒积分价格

_box: 盲盒类型，取值1,2,3

```javascript
function boxPriceOf(uint256 _box)
        external
        view
        returns (uint256 _boxPrice)
```

##### 个人总质押战力

```javascript
function totalPowerOf(address _user)
        external
        view
        returns (uint256 _totalPower)
```

##### 盲盒积分余额

```javascript
function boxBalanceOf(address _user)
        external
        view
        returns (uint256 _balance)
```

##### cvc代币余额

```javascript
function cvcBalanceOf(address _user)
        external
        view
        returns (uint256 _balance)
```

##### 全网总质押战力

```javascript
uint256 public totalPower;
```

写方法

##### 质押

```javascript
function stake(address _nftAddress, uint256 _tokenId)
        external
```

##### 赎回质押

```javascript
function redeem(address _nftAddress, uint256 _tokenId)
        external
```

##### 积分兑换盲盒（提取盲盒）

_box: 盲盒类型，取值1,2,3

_value: 兑换盲盒数量

```javascript
function claimBox(uint256 _box, uint256 _value) external
```

##### 提取cvc代币

```javascript
function claimCVC() external
```

