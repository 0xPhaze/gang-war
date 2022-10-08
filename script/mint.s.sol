// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";
import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

*/

import "futils/futils.sol";

contract mint is SetupChild {
    using futils for *;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        // gmc.setGangsInChunks(0, 39561333442657835159255444834122707128004490012024861285872582601935595435370);
        // gmc.setGangsInChunks(1, 114741522415677814859385012558648876064904699657206083678847582850280262129593);
        // gmc.setGangsInChunks(2, 96552659629366354518216842436741389104263391862876149625883085228389340697945);
        // gmc.setGangsInChunks(3, 77648227528905799494060003497198224745507838538050154708615252362065388426922);
        // gmc.setGangsInChunks(4, 115500384541951941339489684689995994948472865136502830144545638177572416611929);
        // gmc.setGangsInChunks(5, 53111377296646931236336843362356728276951994512882817739866770576857934488950);
        // gmc.setGangsInChunks(6, 78417524658095269468358267154803662969663846233713157151272194439239853581934);
        // gmc.setGangsInChunks(7, 96722037376335619658405798220023795164402148500891274570735600005937037404009);
        gmc.setGangsInChunks(8, 114622315204006287305260434538682499489398188848240971130443895476538083753327);
        gmc.setGangsInChunks(9, 50614575130224761734194063190198056349607842818052061759575873358031939952021);
        gmc.setGangsInChunks(10, 50394728735350630661323228549750195415771628242870795083194284983047817942959);
        gmc.setGangsInChunks(11, 99209114459849345859577475384996110564244786958378768149009161054311797325485);
        gmc.setGangsInChunks(12, 106738653545696903930790526267571427769903766384107643911551777163442842484598);
        gmc.setGangsInChunks(13, 46889620452479344213836804187144557448306323912229576648631691414306879792542);
        gmc.setGangsInChunks(14, 41483319057210372171712956010242765767087112520999307563223305847098546257529);
        gmc.setGangsInChunks(15, 50591172406509967290129754130051214838685714110762258147769488115353438365354);
        gmc.setGangsInChunks(16, 99252395576512881835893572941151881864779184757688317443478933134887984551929);
        gmc.setGangsInChunks(17, 42936755056855542721034632150944232693873320182764149711481589500626633091687);
        gmc.setGangsInChunks(18, 38884096780887735696862326554301688928363466818815893233578979475372665903610);
        gmc.setGangsInChunks(19, 113403187601888244599933478568205160442478721008796225406525335244300157839079);
        gmc.setGangsInChunks(20, 82136079653164654053075288460019404834915271944250832486775746378786621269653);
        gmc.setGangsInChunks(21, 56833274643936586883547112290886450044858224610572943967045431044460485648218);
        gmc.setGangsInChunks(22, 50142225246566634311988707242081240797918053520922655118916706299004642033311);
        gmc.setGangsInChunks(23, 82736988544754923439852411732934561805000474427449248391109061193340777585663);
        gmc.setGangsInChunks(24, 98932140471376896190161921284315698177708240413830111258534533762570363338107);
        gmc.setGangsInChunks(25, 103759264310589581290790802228203016578553183928742111090158549101314771106554);
        gmc.setGangsInChunks(26, 68280989966496496495629508072710583893809995433632427544643996345949732841451);
        gmc.setGangsInChunks(27, 77642173361106320939356240864942494946672318974838078567544096494381210171831);
        gmc.setGangsInChunks(28, 55926782244641875896259738285484958308129964520318405447187106167814979484269);
        gmc.setGangsInChunks(29, 108544466804221234180260556206160007919326485259586247981149794035457902424047);
        gmc.setGangsInChunks(30, 71224845439362057999339205133744660854472512269102963281078199669949804156278);
        gmc.setGangsInChunks(31, 114708279696925014014358275280506890849063863599734028648748792189684788602235);
        gmc.setGangsInChunks(32, 50431963592312447599833065402666167668822564671451880122048593831835644443503);
        gmc.setGangsInChunks(33, 110969886904563470363713237211380221041635300188075869500638582751049767417514);
        gmc.setGangsInChunks(34, 53568784941590069220434027068977261916555618933970905805871798747976872979294);
        gmc.setGangsInChunks(35, 46125267885483705622390930604150154537736824455415470678824758441208980553687);
        gmc.setGangsInChunks(36, 114757763968151415345794361227027136206672096626321086736398464543008633493950);
        gmc.setGangsInChunks(37, 57186592758330505790764929352160297062637633286697610352201024693944569540030);
        gmc.setGangsInChunks(38, 46435105463140088128288576639254545808337619529981126044688313398054507880093);
        gmc.setGangsInChunks(39, 84580506124769847400661042255772474614399603906286424721983091130378810135931);
        gmc.setGangsInChunks(40, 68733876956107133100892815759310251995712471903455811584973312413093762333167);
        gmc.setGangsInChunks(41, 111039242968744267502494442685267188991323457148055614354373281452959028599194);
        gmc.setGangsInChunks(42, 47766099014448792417725339097514191511861199897773951740508467307742003691453);
        gmc.setGangsInChunks(43, 77684244914908350726710732382837007779907641036224605827001064673009075216311);
        gmc.setGangsInChunks(44, 82941818569422420164164933476490364069271606419441261277944941260778476639591);
        gmc.setGangsInChunks(45, 75874779360754392941786781803553010451418424303978028553147765250442374018538);
        gmc.setGangsInChunks(46, 38860883195970668812279926921753884911450305534526671956361911220725735618009);
        gmc.setGangsInChunks(47, 104246830260977585861756103126677080589077893222084141447854682506124162657271);
        gmc.setGangsInChunks(48, 107377327264365168976108017373545469840853042458392917726635264922329183316461);
        gmc.setGangsInChunks(49, 96615496196423171060639516722408650839865490419457600194194337799238763144957);
        gmc.setGangsInChunks(50, 115169936040311442294257703676210515099846134294462824185293275628149539274230);
        gmc.setGangsInChunks(51, 84777455328159525395813724461160747775428021758926730133065866008034087200663);
        gmc.setGangsInChunks(52, 489335);

        // uint256[26] memory chksum = [
        //     uint256(1),
        //     2,
        //     3,
        //     4,
        //     5,
        //     6,
        //     7,
        //     8,
        //     9,
        //     10,
        //     128,
        //     129,
        //     130,
        //     131,
        //     255,
        //     256,
        //     257,
        //     391,
        //     392,
        //     393,
        //     511,
        //     512,
        //     513,
        //     1279,
        //     1280,
        //     1281
        // ];

        // for (uint256 i; i < chksum.length; i++) {
        //     console.log(chksum[i], 1 + uint8(gmc.gangOf(chksum[i])));
        // }

        //         1 2n 2n
        // 2 2n 2n
        // 3 2n 2n
        // 4 1n 1n
        // 5 1n 1n
        // 6 1n 1n
        // 7 3n 3n
        // 8 3n 3n
        // 9 2n 2n
        // 10 3n 3n
        // 128 1n 1n
        // 129 1n 1n
        // 130 2n 2n
        // 131 3n 3n
        // 255 3n 3n
        // 256 3n 3n
        // 257 1n 1n
        // 391 1n 1n
        // 392 3n 3n
        // 393 2n 2n
        // 511 2n 2n
        // 512 2n 2n
        // 513 1n 1n
        // 1279 2n 2n
        // 1280 1n 1n
        // 1281 3n 3n

        // console.log(1, uint8(gmc.gangOf(1))); // Cartel
        // console.log(2, uint8(gmc.gangOf(2))); // Cartel
        // console.log(3, uint8(gmc.gangOf(3))); // Cyberpunk
        // console.log(4, uint8(gmc.gangOf(4))); // Cartel
        // console.log(5, uint8(gmc.gangOf(5))); // Cartel
        // console.log(6, uint8(gmc.gangOf(6))); // Cartel
        // console.log(7, uint8(gmc.gangOf(7))); // Yakuza
        // console.log(8, uint8(gmc.gangOf(8))); // Cartel
        // console.log(9, uint8(gmc.gangOf(9))); // Cyberpunk
        // console.log(10, uint8(gmc.gangOf(10))); // Cartel
        // console.log(128, uint8(gmc.gangOf(128))); // Yakuza
        // console.log(129, uint8(gmc.gangOf(129))); // Yakuza
        // console.log(130, uint8(gmc.gangOf(130))); // Yakuza
        // console.log(131, uint8(gmc.gangOf(131))); // Yakuza
        // console.log(255, uint8(gmc.gangOf(255))); // Cartel
        // console.log(256, uint8(gmc.gangOf(256))); // Cartel
        // console.log(257, uint8(gmc.gangOf(257))); // Cartel
        // console.log(391, uint8(gmc.gangOf(391))); // Cartel
        // console.log(392, uint8(gmc.gangOf(392))); // Cartel
        // console.log(393, uint8(gmc.gangOf(393))); // Cartel
        // console.log(511, uint8(gmc.gangOf(511))); // Cartel
        // console.log(512, uint8(gmc.gangOf(512))); // Yakuza
        // console.log(513, uint8(gmc.gangOf(513))); // Cyberpunk
        // console.log(1279, uint8(gmc.gangOf(1279))); // Yakuza
        // console.log(1280, uint8(gmc.gangOf(1280))); // Yakuza
        // console.log(1281, uint8(gmc.gangOf(1281))); // Yakuza

        vm.stopBroadcast();
    }
}
