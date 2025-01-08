// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import './interfaces/IDMartProject.sol';
import './DMartERC721.sol';
import './interfaces/IDMartFactory.sol';
import './interfaces/IDMartCallee.sol';
import './interfaces/IAavePool.sol';

contract DMartProject {
    uint256 public initialized = 1;

    uint256 public _target;
    uint256 public _raisedAmount = 0;
    uint256 public _collateral;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public _creator;
    address public USDT;
    
	address public aavePool;			// Aave V3 Pool contract address
	address public aaveAsset;			// the asset to interact with Aave (USDT)
	address public aToken;				// the corresponding aToken address
	address public platformAddress;		// the address to receive a share of interests

	uint256 public stakedInAave;		// the principal staked in Aave

    string public _URI;
    uint256 _pahse = 0;
    uint256[] _deadlines;

	uint256 public _tiers;
	uint256[] public _amountsForTiers;
	address[] public _donators;
	mapping(address => uint256) _donatorLevel;
    DMartERC721 public NFT;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Locked.');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier init() {
        require(initialized == 1, "Initialized.");
        _;
        initialized = 2;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint256 indexed id, string indexed URI);
    event Burn(address indexed sender, uint256 indexed id, string indexed URI);
	event AaveDeposit( address indexed caller, uint256 amount );
	event AaveWithdraw( address indexed caller, uint256 requestedPrincipal, uint256 actualPrincipal, uint256 userInterest, uint256 platformInterest, uint256 totalReceived );

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(uint256 target, uint256[] memory amountsForTiers, uint256[] memory deadlines, string memory uri) external init {

        _creator = msg.sender;
        _target = target;
        _tiers = amountsForTiers.length;
        for (uint256 i = 0; i < amountsForTiers.length; i++) {
            _amountsForTiers[i] = amountsForTiers[i];
        }

        _collateral = _target * 2 / 10 / 10^6 * 10^6; // 20% of target as collateral

        for (uint256 i = 0; i < deadlines.length; i++) {
            _deadlines[i] = deadlines[i];
        }
        
        _URI = uri; // store fundrasing details on IPFS
        // https://gateway.pinata.cloud/ipfs/bafybeiekch6rekndqmmmcbpujbk3nptcwbc3lih3pcvc4hcbdeogtv5wru
        
        NFT = new DMartERC721("DMartNFT","DMartNFT");

        uint256 balance = IERC20(USDT).balanceOf(address(_creator));
        require( balance >= _collateral , "Not enough balance to create a projet." );
        IERC20(USDT).transferFrom(_creator, address(this), _collateral);

        depositToAave(_collateral);
    }

    function donate(uint256 tier) external returns(uint256) {
        require(tier < _tiers, "The donating tier doesn't exit");
        uint256 fund = _amountsForTiers[tier];
        _donators.push(msg.sender);
        _donatorLevel[msg.sender] = tier;
        _raisedAmount += fund;

        uint256 balance = IERC20(USDT).balanceOf(msg.sender);
        require( balance >= fund , "Not enough balance to donate." );
        IERC20(USDT).transferFrom(msg.sender, address(this), fund);
        depositToAave(fund);
    }

    function getFundraisingTarget() public view returns(uint256) {
        return _target;
    }

    function getRaisedAmount() public view returns(uint256) {
        return _raisedAmount;
    }

    function getPhase() public view returns(uint256) {
        return _pahse;
    }

	// Aave V3
	function setAaveConfig( address _aavePool, address _aaveAsset, address _aToken, address _platform ) external{
        require( msg.sender == factory, "Only factory can set Aave config." );
        aavePool = _aavePool;
        aaveAsset = _aaveAsset;
        aToken = _aToken;
        platformAddress = _platform;
	}

	function getAaveBalance() public view returns (uint256){
        return ( IERC20( aToken ).balanceOf( address( this ) ) );
	}

	function depositToAave( uint256 amount ) public lock{
        require( ( aavePool != address(0) ) && ( aaveAsset != address(0) ), "Aave config not set." );

        // make sure we have enough balance in the contract
        uint256 balance = IERC20( aaveAsset ).balanceOf( address( this ) );
        require( ( balance >= amount ), "Not enough balance to deposit." );

        // approve Aave Pool
        IERC20( aaveAsset ).approve( aavePool, amount );

        IAavePool( aavePool ).supply( aaveAsset, amount, address( this ), 0 );

        // update the record of the staked asset
        stakedInAave += amount;

        emit AaveDeposit( msg.sender, amount );
	}

	function withdrawFromAave( uint256 principal ) external lock returns ( uint256 actualPrincipal, uint256 userInterest, uint256 platformInterest ){
        require( ( aavePool != address(0) ) && ( aaveAsset != address(0) ), "Aave config not set." );

        require( principal > 0, "Principal must > 0." );
        require( principal <= stakedInAave, "Not enough staked principal in Aave." );

        uint256 totalRedeemable = getAaveBalance();
        uint256 ratio = ( principal * 1e18 ) / stakedInAave;
        uint256 toWithdraw = ( totalRedeemable * ratio ) / 1e18;

        uint256 actualReceived = IAavePool( aavePool ).withdraw( aaveAsset, toWithdraw, address( this ) );

        if( actualReceived > principal ){
            uint256 interest = actualReceived - principal;
            platformInterest = interest / 2;
            userInterest = interest - platformInterest;
            actualPrincipal = principal;

            // distributing the interests
            if( userInterest > 0 ) _safeTransfer( aaveAsset, msg.sender, userInterest );
            if( platformInterest > 0 ) _safeTransfer( aaveAsset, platformAddress, platformInterest );
        }
        else{
                actualPrincipal = actualReceived;
                userInterest = platformInterest = 0;
        }

        stakedInAave -= principal;

        emit AaveWithdraw( msg.sender, principal, actualPrincipal, userInterest, platformInterest, actualReceived );
        return ( actualPrincipal, userInterest, platformInterest );
	}
}
