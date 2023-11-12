import "forge-std/Script.sol";
import "./Helper.sol";
import "../src/ReserveVault.sol";


contract DeployUniswapMessager is Script, Helper {

    function run() external {
        address ccipRouter = 0x70499c328e1E2a3c41108bd3730F6670a44595D1;
        IERC20 asset = IERC20(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889); 
        string memory name = "WMATIC Vault";
        string memory symbol = "TORO1"; 

       ReserveVault vault = new ReserveVault(ccipRouter,asset,name,symbol);
       uint8 decimals = vault.decimals();
       uint256 shares = vault.deposit(8*10**(decimals-1),msg.sender);  
       console.log("Shares minted for deployer ",shares);
      

    
    }    
}
