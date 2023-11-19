pragma solidity ^0.8.19;
import "forge-std/Script.sol";
import "./Helper.sol";
import "../src/ReserveVault.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

// import  "@openzeppelin/contracts/token/ERC20/extensions/IERC20MetaData.sol";


// TODO take my locked reserve back
contract RestoreSender is Script, Helper {

    function run() external {
        IERC4626 vault = IERC4626(0x75866B255B814706fA63C3377cC6715b622D2e53);
        uint256 assetsIn = 4*10**17;
        vault.withdraw( assetsIn, msg.sender, msg.sender);

        
    }    
}


// forge script script/DeployReserveVault.s.sol:DeployVaultSender --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --etherscan-api-key $POLYGON_MUMBAI_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --broadcast 
contract DeployVaultSender is Script, Helper {

    function run() external {
        vm.startBroadcast();
        // polygon mumbai
        (address ccipRouter,address linkToken , , ) = getConfigFromNetwork(SupportedNetworks.POLYGON_MUMBAI);
        ( , , , uint64 destChainID ) = getConfigFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);
        IERC20 asset = IERC20(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889); 
        address deployedVaultAddress = address(0x78D1F42944F99104bE2D7503EEC31d305ee71f5E); 
        // receiver vault backed asset address: 0x6Ec9E796b7AE7020D0fb32CD53cF684c649dFc81
        string memory name = "WMATIC Vault";
        string memory symbol = "TORO1"; 

        ReserveVault vault = new ReserveVault(linkToken, ccipRouter,asset,name,symbol);
        uint8 decimals = vault.decimals();
        
        // when I call safe transfer, the msg.sender is always the call contract
        uint256 assetsIn = 1*10**(decimals-1);
        asset.approve(address(vault),assetsIn);
        uint8 decimalsLink = IERC20Metadata(linkToken).decimals();

        IERC20Metadata(linkToken).transfer(address(vault),10**decimalsLink*2);
        // IERC20Metadata(linkToken).approve(address(vault),10**decimalsLink*2);
        
        uint256 sharesOut = vault.deposit(assetsIn, msg.sender); // real assets transferred to vault
        vault.transferCrossChain( destChainID, deployedVaultAddress , msg.sender , sharesOut , true ); 
        vm.stopBroadcast();
    }    
}


// TODO check total supply and total assets field matching mechanism
// forge script script/DeployReserveVault.s.sol:DeployVaultReceiver --rpc-url $ETHEREUM_SEPOLIA_RPC_URL  --chain-id 11155111 --broadcast  --etherscan-api-key $ETHEREUM_SEPOLIA_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY
contract DeployVaultReceiver is Script, Helper {

    function run() external {
        // Ethereum Sepolia
        vm.startBroadcast();
        (address ccipRouter,address linkToken , , ) = getConfigFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);
        ERC20 wmatic = new ERC20("WMATIC","WMATIC");
        // IERC20 asset = IERC20(0x238a7aB7926fC01DE81a986ff1df5a1223789e42); 
        string memory name = "WMATIC Vault";
        string memory symbol = "TORO1"; 
        ReserveVault vault = new ReserveVault(linkToken,ccipRouter,wmatic,name,symbol);
        console.log("Receiver Vault deployed at ",address(vault));
        console.log("ERC20 Token deployed at ",address(wmatic));
        // uint256 sharesOut = 1*10**17;
        // bytes memory contractCall = abi.encodeWithSignature("mintReserve(uint256,address)",sharesOut,msg.sender);
        // Client.Any2EVMMessage memory message;
        // message.data = contractCall;
        // vault.testCcipReceive(message);
        vm.stopBroadcast();
    //     uint8 decimals = vault.decimals();
    //     uint256 sharesReceived  = 8*10**(decimals-1);
    //    vault.mintReserve( sharesReceived, msg.sender);
    //    console.log( "Shares minted  " , vault.balanceOf(msg.sender));
    //    int256 reserve_ = vault.reserveBalanceOf(msg.sender);
    //    int256 reserve = reserve_ >= 0 ? reserve_ : -reserve_;
    //    if (reserve >= 0) {
    //         console.log( "Reserve minted  " , uint(reserve));
    //    } else {
    //         console.log( "Shares locked  " , uint(reserve));
    //    }

    //    uint8 decimals = vault.decimals();
    //    uint256 shares = vault.deposit(8*10**(decimals-1),msg.sender);  
    //    console.log("Shares minted for deployer ",shares);
        
    
    }    
}
