# Cart Catcher!

Work a shift at Willy Walter’s Mega Shop. Grab carts, dodge shoppers, and push the carts into the blue cart hole before time runs out.

## Play

Open `Cart-Catcher.rbxl` in Roblox Studio and press **Play**. Choose **Solo mode** to play on your own. Choose **Multi** to see public lobbies, enter a seven-character private code, or make a lobby. The host picks the level and starts the shift. Lobbies fit 1–25 players.

Approach a cart and use **Grab cart**. Press **E** on a keyboard, **X** on a gamepad, or tap the prompt. Carts are spread across the front, middle, and back of the store. Steer around pallets, restock racks, sale bins, and wet floors, then push the cart into the blue bay.

If a shopper stops you, your character stays put until the chat ends. Teammates can see a red **Need help!** marker. Get close and press **Q**, press **Y** on a gamepad, or tap **Help**. Hit the green part of the bar to end the chat early. Shoppers stop you once in a while on Easy and more often on harder levels.

| Level | Time | Solo cart goal | 25-player cart goal | Carts in store | Rescue taps | Pay |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Easy | 2:05 | 5 | 25 | 30–70 | 1 | 1× |
| Mediocre | 1:50 | 6 | 34 | 32–94 | 2 | 1.25× |
| IRL | 1:35 | 7 | 45 | 34–124 | 3 | 1.5× |

## Walbucks

Finish the shift and return at least one cart to earn pay. Before the level multiplier, a shift pays 7.50 Walbucks plus 1.25 per cart you return. The crew earns up to 6.00 based on how much it fills the bay, plus a 4.50 bonus for filling it. The game shows pay with USD-style decimals. Walbucks are in-game money. The shop is coming soon.

## Test and publish

- Use Roblox Studio’s **Server & Clients** test mode to try multiplayer on one machine. Studio runs lobbies and wallets for the current test session. Try a shopper stop with two players to see the camera, portrait, red marker, and rescue. The place comes with R6 player and shopper rigs.
- Set **Max Players** to **25** in the published place’s settings. Use the Roblox app to test public listings and private-code joins across servers, then rejoin to check that the wallet saved. [Studio testing](https://create.roblox.com/docs/studio/testing-modes) · [Max Players](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers) · [Roblox teleports](https://create.roblox.com/docs/projects/teleport)

## Build and edit

`src/shared/Config.luau` holds the level settings, and `src/shared/Pay.luau` holds the pay rules. The server runs the lobbies, shifts, and wallet. The client runs the menu, camera, and HUD. The baked store is in `world/WWMS.rbxm`. The R6 rigs are built from `tools/R6Builder.luau`.

With [Rokit](https://github.com/rojo-rbx/rokit) installed, run these commands from the repo.

```sh
rokit install
lune run tools/bake-store.luau
rojo build -o Cart-Catcher.rbxl
```

Skip the bake step when only editing code. For Studio sync, run `rojo serve` and connect with the Rojo Studio plugin. [Roblox Rojo guide](https://create.roblox.com/docs/projects/rojo)
