# Cart Catcher!

Work a shift at Willy Walter’s Mega Shop. Grab carts, dodge shoppers, and push the carts into the blue cart hole before time runs out.

## Play

Open `Cart-Catcher.rbxl` in Roblox Studio and press **Play**. Choose **Solo mode** to play on your own. Choose **Multi** to see public lobbies, enter a seven-character private code, or make a lobby. The host picks the level and starts the shift. Lobbies fit 1–25 players.

Approach a cart and use **Grab cart**. Press **E** on a keyboard, **X** on a gamepad, or tap the prompt. Carts are spread across the front, middle, and back of the store. The edge of each parked cart starts at least 24 studs away from the blue bay on every level. Steer around pallets, restock racks, sale bins, and wet spots, then push the cart into the blue bay. If you step on a wet spot, you drop your cart and take a moment to get back up.

Shoppers browse different departments on their way to checkout. If one stops you, your character stays put until the chat ends. Teammates can see a red **Need help!** marker. Get close and press **Q**, press **Y** on a gamepad, or tap **Help**. Hit the green part of the bar to end the chat early. Shoppers stop you once in a while on Easy and more often on harder levels. The shoppers and Willy Walter wear official Roblox clothes and accessories. The bottom help banner appears during play after you finish your first shift.

| Level | Time | Solo cart goal | 25-player cart goal | Carts in store | Slip time | Leave fee | Rescue taps | Pay |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Easy | 2:05 | 5 | 25 | 40–84 | 1.25 s | 3 | 1 | 1× |
| Mediocre | 1:50 | 6 | 34 | 44–110 | 1.75 s | 5 | 2 | 1.25× |
| IRL | 1:35 | 7 | 45 | 48–142 | 2.30 s | 8 | 3 | 1.5× |

## Walbucks

Finish the shift and return at least one cart to earn pay. Before the level multiplier, a shift pays 7.50 Walbucks plus 1.25 per cart you return. The crew earns up to 6.00 based on how much it fills the bay, plus a 4.50 bonus for filling it. Each part of the pay and every fee rounds to a whole Walbuck. Existing balances round when they load. Walbucks are in-game money. Wallets, purchases, and shift stats use one Roblox DataStore across servers. The balance cannot drop below zero.

## Shift menu and shop

Open **Menu** while playing, press **P** on a keyboard, or click the left stick on a gamepad. Roblox controls its own Escape menu. Closing it after pressing Escape opens the WWMS menu. The timer keeps running while the WWMS menu or shop is open. On a gamepad, move with the stick or D-pad, use **A** to choose, and use **B** to go back. On touch screens, tap the buttons and scroll on short screens. Leaving a shift early, including disconnecting, costs the level’s leave fee.

The shop is on the home and shift menus. It checks Roblox for the current experience’s developer products. To list passes automatically, add the Creator Hub secret `WWMS_SHOP_KEY` for `apis.roblox.com` with read access to game passes in this experience. Check that **Allow HTTP Requests** is enabled. `src/server/ShopItems.luau` also accepts known pass IDs and preview colors for individual IDs. [Roblox passes API](https://create.roblox.com/docs/cloud/reference/features/game-passes) · [Roblox secrets](https://create.roblox.com/docs/cloud-services/secrets)

The shop shows preview items when it has no live items. Browse by category, search by name, or move between pages. The shop loads 12 items and 10 categories per page. Purchasable rows use real Roblox IDs. Developer products add a saved item count by ID. Passes use Roblox ownership. Set an override’s `category` in `ShopItems.luau` to group new items.

## Sound

Calm music plays in menus and between shifts. A livelier mix plays while you work toward the cart goal. Both playlists repeat and fade between songs. Music is courtesy of APM Music and licensed for use in Roblox. The tracks are listed in `src/client/Music.luau`. [Roblox music license](https://en.help.roblox.com/hc/en-us/articles/360000927163-Using-Licensed-Music-on-Roblox)

A short cue plays when you slip. The timer pulses in the last 12 seconds while the cart bay still needs carts. `src/client/SoundEffects.luau` holds the sound clips and volume. The game shares seven local sound slots and uses built-in clips when a store clip fails to load.

## Test and publish

- Use Roblox Studio’s **Server & Clients** test mode to try multiplayer on one machine. Try a shopper stop with two players to see the camera, portrait, red marker, and rescue. The place comes with R6 player and shopper rigs.
- Live servers use the same wallet store. For DataStore tests, open a published test copy in Studio and turn on **Enable Studio Access to API Services** under **File → Experience Settings → Security**. Studio uses a separate wallet scope. An unpublished local file keeps wallets for the current test session. Roblox saves the API access setting on the published experience. [Roblox DataStore setup](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access)
- Set **Max Players** to **25** in the published place’s settings. Use the Roblox app to test public listings and private-code joins across servers, then rejoin to check that the wallet saved. [Studio testing](https://create.roblox.com/docs/studio/testing-modes) · [Max Players](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers) · [Roblox teleports](https://create.roblox.com/docs/projects/teleport)

## Build and edit

`src/shared/Config.luau` holds the level settings, and `src/shared/Pay.luau` holds the pay rules. The server runs the lobbies, shifts, and wallet. The client runs the menu, camera, and HUD. The baked store is in `world/WWMS.rbxm`. The R6 rigs are built from `tools/R6Builder.luau`. To refresh the bundled official clothes and accessories, run `lune run tools/bake-wardrobe.luau` with Python 3 installed, then bake the store.

With [Rokit](https://github.com/rojo-rbx/rokit) installed, run these commands from the repo.

```sh
rokit install
lune run tools/bake-store.luau
rojo build -o Cart-Catcher.rbxl
```

Skip the bake step when only editing code. For Studio sync, run `rojo serve` and connect with the Rojo Studio plugin. [Roblox Rojo guide](https://create.roblox.com/docs/projects/rojo)
