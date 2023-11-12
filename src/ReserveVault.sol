// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import  "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import  "@openzeppelin/contracts/utils/Strings.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "./Util.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";


// import  "@openzeppelin/contracts/interfaces/IERC4626.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReserveVault is ERC4626, Util, CCIPReceiver {

    bytes32 public latestMessageId;
    uint64 public latestSourceChainSelector;
    address public latestSender;
    string public latestMessage;
    bytes32 public latestArgs;
    event MessageSent(bytes32 messageId);
    enum PayFeesIn {
        Native,
        LINK
    }
    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        string latestMessage
    );
    // mapping(address => uint256) private _ReserveBalances;
    // mapping(address => mapping(address => uint256)) private _ReserveAllowances;
    // Note the reserve can be negative 
    int256 private _totalReserveShares;
    mapping(address => int256) private _reserveShareBalances;
    // I am thinking total balance is the net , while reserve balance is just a tracker
    receive() external payable {}
    address immutable _link;


    constructor(address linkToken, address ccipRouter, IERC20 asset, string memory name, string memory symbol ) CCIPReceiver(ccipRouter) ERC4626 (asset) ERC20(name,symbol) {
        _link = linkToken;
    }

    function maxReserve(address) public pure returns (int256) {
        return type(int256).max;
    }

    function minReserve(address) public pure  returns (int256) {
        return type(int256).min;
    }

    function transferCrossChain(uint64 destinationChainSelector,
        address receiver,
        uint256 sharesOut,
        bool useLink) public returns (bytes32 messageId) {
        
        
        bytes memory contractCall = abi.encodeWithSignature("mintReserve(uint256,address)",sharesOut,receiver);
        // string memory messageText =  bytesToHexString(abi.encodeWithSignature(mintReserve.selector,sharesOut,receiver));
        PayFeesIn payFeesIn = useLink? PayFeesIn.LINK:PayFeesIn.Native;
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: contractCall,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? _link : address(0)
        });

        uint256 fee = IRouterClient(getRouter()).getFee(
            destinationChainSelector,
            message
        );

        if (payFeesIn == PayFeesIn.LINK) {
            //  LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = IRouterClient(getRouter()).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            messageId = IRouterClient(getRouter()).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
        }

        emit MessageSent(messageId);
        _burnReserve(sharesOut, msg.sender);
    }
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));

        emit MessageReceived(
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
        (bool success, ) = address(this).call(message.data);
        require(success, "Method call failed");
    }

    function mintReserve(uint256 shares, address receiver) public onlyRouter returns(bool) {
        
        uint256 assets = convertToAssets(shares);
        _totalReserveShares = addUint256ToInt256(_totalReserveShares, assets);
        // shares must be backed by either reserve or actual balance
        _reserveShareBalances[receiver] = addUint256ToInt256(_reserveShareBalances[receiver], assets);
        
        require(maxReserve(receiver) >= _reserveShareBalances[receiver],"Reserve Upperbound Hit");

        
        _mint(receiver, shares);
        return true;
    }

    

    function _burnReserve(uint256 shares, address sender) private  returns(bool) {
        uint256 assets = convertToAssets(shares);

        _totalReserveShares = subtractUint256FromInt256(_totalReserveShares, assets);
        // shares must be backed by either reserve or actual balance
        _reserveShareBalances[sender] = subtractUint256FromInt256(_reserveShareBalances[sender], assets);
        require(minReserve(sender)<= _reserveShareBalances[sender],"Reserve Lowerbound Hit");

        
        _burn(sender, shares);

        return true;
    }


    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return safeAddIntToUint(_reserveShareBalances[owner], balanceOf(owner)) ;
    }

    function maxWithdraw(address owner) public view virtual override returns (uint256) {

        return _convertToAssets(safeAddIntToUint(_reserveShareBalances[owner], balanceOf(owner)),Math.Rounding.Down) ;
    }
    // function balanceOf(address account) public view override(IERC20, ERC20) returns (uint256){
    //     return ERC20.balanceOf(account) + _reserveBalances[account];
    // }


    // override maxWithdraw, it means you cannot withdraw more than
    // Context
    // // Override withdraw
    // function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
    //     require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

    //     uint256 shares = previewWithdraw(assets);
    //     _withdraw(_msgSender(), receiver, owner, assets, shares);

    //     return shares;
    // } 


    // function maxWithdraw(address owner) public view virtual override returns (uint256) {
    //     return _convertToAssets(ERC20.balanceOf(owner), Math.Rounding.Down);
    // }

}