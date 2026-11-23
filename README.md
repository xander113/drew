# Cart Catcher!

A co-op Roblox game set in Willy Walter’s Mega Shop. Clock in, collect carts around the store, and push them into the marked cart hole before the shift ends. Shoppers chase workers and briefly slow anybody they catch.

## Play in Roblox Studio

Open `Cart-Catcher.rbxl` directly in Roblox Studio and use **Play**. Select **Clock In** to start the ten-second briefing. Walk up to a cart and use the prompt. Walk into the blue cart hole to return it automatically.

- The first worker can start a shift alone. A server can seat up to 25 workers. Players who clock in during a shift join the next one.
- Workers advance after filling the cart hole and repeat the same level after running out of time. Choose **Clock Out** between shifts to leave the queue.
- Before publishing, set **Max Players** to **25** in the published place’s settings. The place file enforces a 25-worker limit in gameplay. [Roblox Players documentation](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers)

| Level | Time | Solo target | 25-worker target |
| --- | ---: | ---: | ---: |
| Easy | 2:05 | 4 | 22 |
| Mediocre | 1:50 | 5 | 30 |
| IRL | 1:35 | 6 | 40 |

## Build and edit

`src/shared/Config.luau` contains the timings, goals, and difficulty scaling. `src/server` controls shifts, cart ownership, and shoppers. `src/client` controls the menu, in-game HUD, and camera. The baked store lives in `world/WWMS.rbxm`. `tools/StoreBuilder.luau` generates the store using coordinates shared in `src/shared/Layout.luau`.

With [Rokit](https://github.com/rojo-rbx/rokit) installed, run the following from the source folder.

```sh
rokit install
lune run tools/bake-store.luau
rojo build -o Cart-Catcher.rbxl
```

The source archive includes the baked store, so you can skip rebaking when editing gameplay scripts. To sync with Studio while editing, run `rojo serve` and connect from the Rojo Studio plugin. [Roblox Rojo documentation](https://create.roblox.com/docs/projects/rojo)
