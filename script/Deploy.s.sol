// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

import {BulletinFactory} from "src/BulletinFactory.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {Currency} from "src/Currency.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    // Events.

    // Errors.
    error Invalid();

    // Constant.
    bytes32 constant TEST_BYTES32 = "TEST";
    string constant TEST_STRING = "TEST";
    bytes constant TEST_BYTES = "TEST";

    // Contracts.
    address payable bulletinAddr =
        payable(address(0x51552eEE4ddB068165a07dC0D002336a817175F9));
    address factoryAddr = address(0);

    // Tokens.
    address currencyAddr = address(0xae1669d63dFcb827dd5A4ea9B7A000eFCe84C90a);
    address currencyAddr2 = address(0);

    // Users.
    address account;
    address user1 = address(0x4744cda32bE7b3e75b9334001da9ED21789d4c0d);
    address user2 = address(0xFB12B6A543d986A1938d2b3C7d05848D8913AcC4);
    address user3 = address(0x85E70769d04Be1C9d7C3c373b98BD9929f61F428);
    address gasbot = address(0x7Cf60ec5A5541b7d4073F795a67A75E383F3FFFf);

    // Bulletin Roles.
    uint40 PERMISSIONED = 1 << 2;

    /// @notice The main script entrypoint.
    function run() external {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        account = vm.addr(privateKey);

        console2.log("Account", account);

        vm.startBroadcast(privateKey);

        // Bulletin(bulletinAddr).exchange(
        //     1,
        //     IBulletin.Trade({
        //         approved: false,
        //         from: account,
        //         resource: 0,
        //         currency: currencyAddr,
        //         amount: 2 ether,
        //         content: TEST_STRING,
        //         data: TEST_BYTES
        //     })
        // );

        // deployCurrency(account);

        // Grant permissions
        // Bulletin(bulletinAddr).grantRoles(user1, PERMISSIONED);

        // Approve trades
        // Bulletin(bulletinAddr).approveTrade(1, 1);

        // factoryAddr = deployBulletinFactory();
        // deployBulletin(factoryAddr, user1);

        // Currency(currencyAddr).mint(
        //     0xc9e677d8a064808717C2F38b5d6Fe9eE69C1fa6a,
        //     40 ether
        // );

        // uint256 balance = Currency(currencyAddr).balanceOf(account);
        // emit IBulletin.RequestUpdated(balance);

        // Currency(currencyAddr).approve(bulletinAddr, 40 ether);

        // uint256 allow = Currency(currencyAddr).allowance(
        //     0xc9e677d8a064808717C2F38b5d6Fe9eE69C1fa6a,
        //     0xdbe8B7a2C394dBcE1895EBA5c622D5A646eA22c4
        // );

        // Currency(currencyAddr).approve(
        //     0x1C17c048111809503d8d44F760aAA0bFAEf2edf3,
        //     40 ether
        // );

        // allow = Currency(currencyAddr).allowance(
        //     0xc9e677d8a064808717C2F38b5d6Fe9eE69C1fa6a,
        //     0x1C17c048111809503d8d44F760aAA0bFAEf2edf3
        // );

        // emit IBulletin.RequestUpdated(allow);

        // IBulletin.Request memory req = IBulletin.Request({
        //     from: account,
        //     title: unicode"大松報到 | Check-in",
        //     detail: unicode"報到成功可獲取 2 $ARM0RY | Recieve 2 $ARM0RY for checking in",
        //     currency: currencyAddr,
        //     drop: 20 ether
        // });
        // Bulletin(bulletinAddr).request(req);

        // req = IBulletin.Request({
        //     from: account,
        //     title: unicode"維護環境小小松 | BYO-Utensils",
        //     detail: unicode"回覆成功可獲取 2 $ARM0RY | Recieve 2 $ARM0RY for responding",
        //     currency: currencyAddr,
        //     drop: 20 ether
        // });
        // Bulletin(bulletinAddr).requestByAgent(req);

        // IBulletin.Resource memory res = IBulletin.Resource({
        //     from: user1,
        //     title: unicode"閒聊區塊鏈應用 | Chat about web3",
        //     detail: ""
        // });
        // Bulletin(bulletinAddr).resourceByAgent(res);

        // res = IBulletin.Resource({
        //     from: user1,
        //     title: unicode"協助開啟以太坊錢包 | Get an Ethereum wallet address",
        //     detail: ""
        // });
        // Bulletin(bulletinAddr).resourceByAgent(res);

        Bulletin(bulletinAddr).approveResponse(1, 1, 2 ether);
        Bulletin(bulletinAddr).approveResponse(1, 2, 2 ether);
        Bulletin(bulletinAddr).approveResponse(2, 1, 2 ether);
        Bulletin(bulletinAddr).approveResponse(2, 3, 2 ether);

        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Deploy Contracts.                             */
    /* -------------------------------------------------------------------------- */

    function deployBulletinFactory() internal returns (address bf) {
        address temp = payable(address(new Bulletin()));
        bf = address(new BulletinFactory(temp));
    }

    function deployBulletin(address factory, address user) internal {
        delete bulletinAddr;

        if (factory != address(0)) {
            BulletinFactory(factoryAddr).deployBulletin(TEST_BYTES32, user);
            bulletinAddr = payable(
                BulletinFactory(factoryAddr).determineBulletin(TEST_BYTES32)
            );
        } else {
            bulletinAddr = payable(address(new Bulletin()));
            Bulletin(bulletinAddr).init(user);
        }
    }

    function deployCurrency(address owner) internal {
        currencyAddr = address(new Currency(owner));
    }

    // function deployCurrency2(
    //     string memory name,
    //     string memory symbol,
    //     address owner
    // ) internal {
    //     delete currencyAddr2;
    //     currencyAddr2 = address(new Currency(name, symbol, owner));
    // }

    // function support(
    //     uint256 curveId,
    //     address patron,
    //     uint256 amountInCurrency
    // ) internal {
    //     uint256 price = TokenCurve(marketAddr).getCurvePrice(true, curveId, 0);
    //     TokenCurve(marketAddr).support{value: price}(
    //         curveId,
    //         patron,
    //         amountInCurrency
    //     );
    // }

    // function registerList(
    //     address user,
    //     address bulletin,
    //     Item[] memory _items,
    //     string memory listTitle,
    //     string memory listDetail,
    //     uint256 drip
    // ) internal {
    //     delete itemIds;
    //     uint256 itemId = IBulletin(bulletinAddr).itemId();

    //     IBulletin(bulletinAddr).registerItems(_items);

    //     for (uint256 i = 1; i <= _items.length; ++i) {
    //         itemIds.push(itemId + i);
    //     }

    //     List memory list = List({
    //         owner: user,
    //         title: listTitle,
    //         detail: listDetail,
    //         schema: BYTES,
    //         itemIds: itemIds,
    //         drip: drip
    //     });
    //     IBulletin(bulletinAddr).registerList(list);
    // }

    /* -------------------------------------------------------------------------- */
    /*                                    Old.                                    */
    /* -------------------------------------------------------------------------- */

    // function deployGfel(address patron, address user) internal {
    //     // Deploy quest contract and set gasbot.
    //     deployLogger(false, patron);

    //     // Deploy bulletin contract and grant roles.
    //     deployBulletin(false, patron);
    //     IBulletin(bulletinAddr).grantRoles(
    //         loggerAddr,
    //         IBulletin(bulletinAddr).LOGGERS()
    //     );

    //     // Prepare lists.
    //     registerCoffee();

    //     // Deploy token minter and uri builder.
    //     deployTokenMinter();
    //     deployTokenBuilder();

    //     // Deploy curve.
    //     deployTokenCurve(patron);

    //     // Deploy currency.
    //     // deployCurrency("General Forum on Ethereum Localism", "GFEL", patron);
    //     // Currency(currencyAddr).mint(patron, 1000 ether, marketAddr);
    //     // Currency(currencyAddr).mint(marketAddr, 10 ether, marketAddr);
    //     // Currency(currencyAddr).mint(user1, 50 ether, marketAddr);

    //     // Configure token
    //     ITokenMinter(tokenMinterAddr).registerMinter(
    //         TokenMetadata({
    //             name: "Coffee at GFEL",
    //             symbol: "$GFEL Coffee",
    //             desc: "Coffee is free and we accept $3 donation per cup!"
    //         }),
    //         TokenSource({
    //             user: address(0),
    //             bulletin: bulletinAddr,
    //             listId: 1,
    //             logger: loggerAddr
    //         }),
    //         TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
    //         TokenMarket({market: marketAddr, limit: 100})
    //     );
    //     uint256 tokenId = ITokenMinter(tokenMinterAddr).tokenId();

    //     // Register curves.
    //     curve1 = Curve({
    //         owner: user,
    //         token: tokenMinterAddr,
    //         id: tokenId,
    //         supply: 0,
    //         curveType: CurveType.LINEAR,
    //         currency: currencyAddr2,
    //         scale: 0.001 ether,
    //         mint_a: 0,
    //         mint_b: 10,
    //         mint_c: 3000,
    //         burn_a: 0,
    //         burn_b: 0,
    //         burn_c: 0
    //     });
    //     TokenCurve(marketAddr).registerCurve(curve1);

    //     // Update admin.
    //     // Need this only if deployer account is different from account operating the contract
    //     Bulletin(payable(bulletinAddr)).transferOwnership(user);

    //     // Submit mock user input.
    //     ILog(loggerAddr).log(
    //         CROISSANT,
    //         bulletinAddr,
    //         1,
    //         0,
    //         "Smooooth!",
    //         abi.encode(uint256(1), uint256(4))
    //     );

    //     // Full stablecoin support.
    //     // uint256 price = TokenCurve(marketAddr).getCurvePrice(true, 1, 0);
    //     // TokenCurve(marketAddr).support{value: price}(1, patron, 0);

    //     // Floor currency support.
    //     // price = TokenCurve(marketAddr).getCurvePrice(true, 2, 0);
    //     // TokenCurve(marketAddr).support{value: price - 3 ether}(
    //     //     2,
    //     //     patron,
    //     //     3 ether
    //     // );

    //     // Grant AUTHORIZED_TOKENS role.
    //     // ILog(loggerAddr).grantRoles(
    //     //     address(
    //     //         uint160(uint256(keccak256(abi.encode(tokenMinterAddr, 1))))
    //     //     ),
    //     //     AUTHORIZED_TOKENS
    //     // );

    //     // Patron log
    //     // ILog(loggerAddr).logByToken(
    //     //     CROISSANT,
    //     //     tokenMinterAddr,
    //     //     1,
    //     //     AUTHORIZED_TOKENS,
    //     //     0,
    //     //     "Flavorful!",
    //     //     abi.encode(uint256(1), uint256(7))
    //     // );
    // }

    // function deployCommons(address patron, address user) internal {
    //     // Deploy quest contract and set gasbot.
    //     deployLogger(false, patron);
    //     ILog(loggerAddr).grantRoles(patron, CROISSANT);
    //     ILog(loggerAddr).grantRoles(patron, MEMBERS);
    //     ILog(loggerAddr).grantRoles(user1, MEMBERS);
    //     ILog(loggerAddr).grantRoles(user1, STAFF);

    //     // Deploy bulletin contract and grant roles.
    //     deployBulletin(false, patron);
    //     IBulletin(bulletinAddr).grantRoles(
    //         loggerAddr,
    //         IBulletin(bulletinAddr).LOGGERS()
    //     );

    //     // Prepare lists.
    //     registerCoffee();
    //     registerDeliverCoffee();

    //     // Deploy token minter and uri builder.
    //     deployTokenMinter();
    //     deployTokenBuilder();

    //     // Deploy curve.
    //     deployTokenCurve(patron);

    //     // Deploy currency.
    //     deployCurrency("Coffee", "COFFEE", patron);
    //     Currency(currencyAddr).mint(patron, 1000 ether, marketAddr);
    //     Currency(currencyAddr).mint(marketAddr, 10 ether, marketAddr);
    //     Currency(currencyAddr).mint(user1, 50 ether, marketAddr);

    //     deployCurrency2("Croissant", "CROISSANT", patron);
    //     Currency(currencyAddr2).mint(patron, 1000 ether, marketAddr);
    //     Currency(currencyAddr2).mint(marketAddr, 10 ether, marketAddr);
    //     Currency(currencyAddr2).mint(user1, 50 ether, marketAddr);

    //     // Configure token
    //     ITokenMinter(tokenMinterAddr).registerMinter(
    //         TokenMetadata({
    //             name: "Coffee with $croissant",
    //             symbol: "Coffee with $croissant",
    //             desc: "For the $croissant community, we offer our coffee for 5 $croissant. Redeem a cup of coffee with this token at our shop in Chiado, Portugal."
    //         }),
    //         TokenSource({
    //             user: address(0),
    //             bulletin: bulletinAddr,
    //             listId: 1,
    //             logger: loggerAddr
    //         }),
    //         TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
    //         TokenMarket({market: marketAddr, limit: 100})
    //     );
    //     uint256 tokenId = ITokenMinter(tokenMinterAddr).tokenId();

    //     ITokenMinter(tokenMinterAddr).registerMinter(
    //         TokenMetadata({
    //             name: "Coffee",
    //             symbol: "Coffee",
    //             desc: "Giving back to the $coffee community, we take 3 $coffee and some in $stablecoins for our continued commitment in sourcing local beans and practicing sustainable waste practices. You may redeem a cup of coffee with this token at our shop in Chiado, Portugal, or burn this token at a later date for some profit. It's like reselling early bird tickets. The choice is yours."
    //         }),
    //         TokenSource({
    //             user: address(0),
    //             bulletin: bulletinAddr,
    //             listId: 1,
    //             logger: loggerAddr
    //         }),
    //         TokenBuilder({builder: tokenBuilderAddr, builderId: 2}),
    //         TokenMarket({market: marketAddr, limit: 300})
    //     );
    //     uint256 tokenId2 = ITokenMinter(tokenMinterAddr).tokenId();

    //     ITokenMinter(tokenMinterAddr).registerMinter(
    //         TokenMetadata({
    //             name: "[Service] Deliver a Pitcher of Coffee",
    //             symbol: "Deliver a Pitcher of Coffee",
    //             desc: "We can deliver a pitcher of cold brew for 10 $coffee to cover labor, and some in $stablecoin for our commitment to reuse and deliver pitchers with zero-emission."
    //         }),
    //         TokenSource({
    //             user: address(0),
    //             bulletin: bulletinAddr,
    //             listId: 2,
    //             logger: loggerAddr
    //         }),
    //         TokenBuilder({builder: tokenBuilderAddr, builderId: 3}),
    //         TokenMarket({market: marketAddr, limit: 20})
    //     );
    //     uint256 tokenId3 = ITokenMinter(tokenMinterAddr).tokenId();

    //     ITokenMinter(tokenMinterAddr).registerMinter(
    //         TokenMetadata({
    //             name: "[Help Wanted] Deliver a Pitcher of Coffee",
    //             symbol: "Deliver a Pitcher of Coffee",
    //             desc: "Reserve a spot with 0.5 $coffee to help us deliver with zero-emission. Join our Discord for more delivery detail~"
    //         }),
    //         TokenSource({
    //             user: user1,
    //             bulletin: bulletinAddr,
    //             listId: 2,
    //             logger: loggerAddr
    //         }),
    //         TokenBuilder({builder: tokenBuilderAddr, builderId: 4}),
    //         TokenMarket({market: marketAddr, limit: 3})
    //     );
    //     uint256 tokenId4 = ITokenMinter(tokenMinterAddr).tokenId();

    //     // ITokenMinter(tokenMinterAddr).registerMinter(
    //     //     TokenMetadata({
    //     //         name: "[Harberger Sponsor] How to Make Espresso for Beginners",
    //     //         desc: "[WIP] Our espresso-making process is a one-of-a-kind artistic endeavor. If you want to know more, show your support and become a Harberger sponsor!"
    //     //     }),
    //     //     TokenSource({bulletin: bulletinAddr, listId: 4, logger: loggerAddr}),
    //     //     TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
    //     //     TokenMarket({market: marketAddr, limit: 1})
    //     // );
    //     // uint256 tokenId5 = ITokenMinter(tokenMinterAddr).tokenId();

    //     // Register curves.
    //     curve1 = Curve({
    //         owner: user1,
    //         token: tokenMinterAddr,
    //         id: tokenId,
    //         supply: 0,
    //         curveType: CurveType.LINEAR,
    //         currency: currencyAddr2,
    //         scale: 1 ether,
    //         mint_a: 0,
    //         mint_b: 0,
    //         mint_c: 5,
    //         burn_a: 0,
    //         burn_b: 0,
    //         burn_c: 0
    //     });
    //     TokenCurve(marketAddr).registerCurve(curve1);

    //     curve2 = Curve({
    //         owner: user2,
    //         token: tokenMinterAddr,
    //         id: tokenId2,
    //         supply: 0,
    //         curveType: CurveType.LINEAR,
    //         currency: currencyAddr,
    //         scale: 0.0001 ether,
    //         mint_a: 0,
    //         mint_b: 30,
    //         mint_c: 30000,
    //         burn_a: 0,
    //         burn_b: 1,
    //         burn_c: 0
    //     });
    //     TokenCurve(marketAddr).registerCurve(curve2);

    //     curve3 = Curve({
    //         owner: user1,
    //         token: tokenMinterAddr,
    //         id: tokenId3,
    //         supply: 0,
    //         curveType: CurveType.LINEAR,
    //         currency: currencyAddr,
    //         scale: 0.0001 ether,
    //         mint_a: 0,
    //         mint_b: 100,
    //         mint_c: 100000,
    //         burn_a: 0,
    //         burn_b: 1,
    //         burn_c: 0
    //     });
    //     TokenCurve(marketAddr).registerCurve(curve3);

    //     curve4 = Curve({
    //         owner: user2,
    //         token: tokenMinterAddr,
    //         id: tokenId4,
    //         supply: 0,
    //         curveType: CurveType.QUADRATIC,
    //         currency: currencyAddr,
    //         scale: 0.01 ether,
    //         mint_a: 0,
    //         mint_b: 8,
    //         mint_c: 50,
    //         burn_a: 0,
    //         burn_b: 1,
    //         burn_c: 0
    //     });
    //     TokenCurve(marketAddr).registerCurve(curve4);

    //     // Update admin.
    //     // Need this only if deployer account is different from account operating the contract
    //     Bulletin(payable(bulletinAddr)).transferOwnership(user);

    //     // Submit mock user input.
    //     ILog(loggerAddr).log(
    //         CROISSANT,
    //         bulletinAddr,
    //         1,
    //         0,
    //         "So smooth!",
    //         abi.encode(uint256(0), uint256(4))
    //     );
    //     ILog(loggerAddr).log(
    //         MEMBERS,
    //         bulletinAddr,
    //         2,
    //         0,
    //         "Sold",
    //         abi.encode(0.02 ether, 0.2 ether, 0.002 ether)
    //     );

    //     // Full stablecoin support.
    //     uint256 price = TokenCurve(marketAddr).getCurvePrice(true, 1, 0);
    //     TokenCurve(marketAddr).support(1, patron, price);

    //     // Floor currency support.
    //     price = TokenCurve(marketAddr).getCurvePrice(true, 2, 0);
    //     TokenCurve(marketAddr).support{value: price - 3 ether}(
    //         2,
    //         patron,
    //         3 ether
    //     );

    //     // Partial-floor stablecoin support.
    //     price = TokenCurve(marketAddr).getCurvePrice(true, 3, 0);
    //     TokenCurve(marketAddr).support{value: price - 9.9995 ether}(
    //         3,
    //         patron,
    //         9.9995 ether
    //     );

    //     // Floor currency support.
    //     price = TokenCurve(marketAddr).getCurvePrice(true, 4, 0);
    //     TokenCurve(marketAddr).support{value: price - 0.5 ether}(
    //         4,
    //         patron,
    //         0.5 ether
    //     );

    //     // Grant AUTHORIZED_TOKENS role.
    //     ILog(loggerAddr).grantRoles(
    //         address(
    //             uint160(uint256(keccak256(abi.encode(tokenMinterAddr, 1))))
    //         ),
    //         AUTHORIZED_TOKENS
    //     );

    //     // Patron log
    //     ILog(loggerAddr).logByToken(
    //         CROISSANT,
    //         tokenMinterAddr,
    //         1,
    //         AUTHORIZED_TOKENS,
    //         0,
    //         "Flavorful!",
    //         abi.encode(uint256(1), uint256(7))
    //     );
    // }

    /* -------------------------------------------------------------------------- */
    /*                                Custom Lists.                               */
    /* -------------------------------------------------------------------------- */

    // function registerCoffee() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "ABC Beans",
    //         detail: "https://hackmd.io/@audsssy/rkHLIFwVC",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Filtered Water",
    //         detail: "https://hackmd.io/@audsssy/rJ__K2vEC",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Compost Coffee Grounds",
    //         detail: "https://www.youtube.com/embed/z_rIUz17mR4",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "Coffee at GFEL",
    //         "A smooth and refreshing coffee experience crafted to balance bold flavors and ethical sourcing.",
    //         0
    //     );
    // }

    // function registerDeliverCoffee() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Grab a Pitcher",
    //         detail: "https://hackmd.io/@audsssy/r1PJocwEC",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Deliver to Recipient",
    //         detail: "https://www.youtube.com/embed/gcUi_wA5UuI",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Recycle Pitcher",
    //         detail: "https://www.youtube.com/embed/bCKNvoncsvk",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "Deliver a Pitcher of Coffee",
    //         "Reserve a pitcher of Coffee for delivery next Monday!",
    //         60 ether
    //     );
    // }

    // function registerEspresso() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "ABC Espresso Beans",
    //         detail: "https://hackmd.io/@audsssy/rkHLIFwVC",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Boiled Water",
    //         detail: "",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "Espresso",
    //         "Discover our expertly crafted espresso, delivering bold, rich flavor and a velvety crema, perfect for starting your day with a touch of excellence.",
    //         0
    //     );
    // }

    // function registerMakingEspresso() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Preheat Machine",
    //         detail: "https://hackmd.io/@audsssy/BJHHDtPEA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Grind Beans",
    //         detail: "https://hackmd.io/@audsssy/SkN9wYv40",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Tamp Coffee",
    //         detail: "https://hackmd.io/@audsssy/rJ__K2vEC",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item4 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Brew Espresso",
    //         detail: "https://www.youtube.com/embed/fbHPjiST8Is",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);
    //     items.push(item4);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "Making Espresso",
    //         "Making an espresso is an art. We want to share with you how we do it.",
    //         0
    //     );
    // }

    // function registerChiadoPoloHat() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "6-panel",
    //         detail: "https://hackmd.io/@audsssy/HJC9SFvNA",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "Chiado Polo Hat",
    //         "Chiado Coffee brings you the best looking outfit that makes you proud.",
    //         0
    //     );
    // }

    // function registerHackath0n() public {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: unicode"第陸拾次記得投票黑客松 － 60th Hackath0n",
    //         detail: "https://g0v.hackmd.io/@jothon/B1IwtQNrT",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: unicode"第陸拾壹次龍來 Open Data Day 黑客松 － 61st Hackath0n",
    //         detail: "https://g0v.hackmd.io/@jothon/B1DqSeaK6",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "g0v bi-monthly Hackath0n",
    //         "Founded in Taiwan, 'g0v' (gov-zero) is a decentralised civic tech community with information transparency, open results and open cooperation as its core values. g0v engages in public affairs by drawing from the grassroot power of the community.",
    //         0
    //     );
    // }

    // function registerListTutorial() internal {
    //     delete items;
    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Navigating the 'Create a Task' page",
    //         detail: "https://hackmd.io/@audsssy/H1bZW6h66",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user2,
    //         title: "Navigating the 'Create a List' page",
    //         detail: "https://hackmd.io/@audsssy/rJrera2TT",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Navigating Lists",
    //         detail: "https://hackmd.io/@audsssy/BkrQSah6p",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "'Create a List' Tutorial",
    //         "This is a tutorial to create, and interact with, a list onchain.",
    //         0
    //     );
    // }

    // function registerWildernessPark() internal {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user2,
    //         title: "Trail Post #45",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user1,
    //         title: "Trail Post #44",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Trail Post #43",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item4 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user2,
    //         title: "Trail Post #28",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item5 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Trail Post #29",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item6 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Trail Post #48",
    //         detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);
    //     items.push(item4);
    //     items.push(item5);
    //     items.push(item6);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "TESTNET Wilderness Park",
    //         "Scan QR codes at each trail post to help build a real-time heat map of hiking activities!",
    //         0
    //     );
    // }

    // function registerStoryTime() internal {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Seeing Practice Seeing Clearly by Tara Brach",
    //         detail: "https://www.youtube.com/embed/aoypkPAB1aA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Feather (feat. Cise Starr &amp; Akin from CYNE)",
    //         detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Luv(sic.) pt3 (feat. Shing02)",
    //         detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item4 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "After Hanabi -listen to my beats-",
    //         detail: "https://www.youtube.com/embed/UkhVp85_BnA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item5 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Counting Stars",
    //         detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);
    //     items.push(item4);
    //     items.push(item5);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         unicode"Storytime with Aster // 胖比媽咪說故事",
    //         "",
    //         0
    //     );
    // }

    // function registerNujabes() internal {
    //     delete items;

    //     Item memory item1 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Aruarian Dance",
    //         detail: "https://www.youtube.com/embed/HkZ8BitJhvc",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item2 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Feather (feat. Cise Starr &amp; Akin from CYNE)",
    //         detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item3 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Luv(sic.) pt3 (feat. Shing02)",
    //         detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item4 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "After Hanabi -listen to my beats-",
    //         detail: "https://www.youtube.com/embed/UkhVp85_BnA",
    //         schema: BYTES,
    //         drip: 0
    //     });
    //     Item memory item5 = Item({
    //         review: false,
    //         expire: FUTURE,
    //         owner: user3,
    //         title: "Counting Stars",
    //         detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
    //         schema: BYTES,
    //         drip: 0
    //     });

    //     items.push(item1);
    //     items.push(item2);
    //     items.push(item3);
    //     items.push(item4);
    //     items.push(item5);

    //     registerList(
    //         account,
    //         bulletinAddr,
    //         items,
    //         "The Nujabes Musical Collection",
    //         "Just a few tracks from the Japanese legend, the original lo-fi master that inspired the entire chill genre. Enjoy!",
    //         0
    //     );
    // }
}
