# Gameplay features

What Goomba XI changes from a stock LandSandBoat server, and where to change each thing. Everything here lives in this repository: edit the file, then `sudo goomba apply && sudo goomba restart game`, and commit the change so it isn't lost on the next update.

## Era

- The original game, Rise of the Zilart, Chains of Promathia and Treasures of Aht Urhgan. Wings of the Goddess and later are off (`ENABLE_<EXPANSION>` in `settings/main.lua`; keep `GOOMBA_ERA_MODULES` in `/etc/goomba/goomba.conf` in step).
- Level cap 50, raised to 75 through Maat's Limit Break quests (`INITIAL_LEVEL_CAP`, `MAX_LEVEL`).
- Later systems (Records of Eminence, Field and Grounds of Valor manuals, home-point teleports, Mog Garden, …) are off.

## Rates

| What | Setting | File | Goomba XI value |
| --- | --- | --- | --- |
| Experience from kills | `EXP_RATE` | `map.lua` | 3.0 |
| Experience from quests and scrolls | `EXP_RATE` | `main.lua` | 3.0 (keep equal to `map.lua`) |
| Combat and magic skill-ups | `SKILLUP_AMOUNT_MULTIPLIER` | `map.lua` | 2 (about 3× a normal gain) |
| Crafting skill-up chance | `CRAFT_CHANCE_MULTIPLIER` | `map.lua` | 2.0 |
| Fishing | `FISHING_ENABLE` | `map.lua` | true (LandSandBoat ships it off) |
| Fishing skill-up chance | `FISHING_SKILL_MULTIPLIER` | `map.lua` | 2.0 |

Drop rates are retail.

## Trusts, for solo and small-group play

In `modules/goomba/lua/solo_trusts.lua` and `trust_shop.lua`:

- Up to five trusts at once (`maxTrusts`).
- Every character knows five from the first login: Excenmille, Kupipi, Naji, Ayame and Shantotto — a tank, a healer, two melee and a black mage (`starterTrusts`).
- Retail zone and battlefield rules (`everywhere = false`): no trusts in towns or in battles that forbid them, and only a solo player or the party leader can call them.
- Trusts whose main job is Geomancer, Rune Fencer, Dancer or Scholar are blocked — those jobs postdate the 75 era (`blockedTrusts`). A blocked trust can't be cast even if it is learned some other way.
- The **Trust Liaison** in Lower Jeuno sells the other 102 trusts for conquest points, in tiers that open when any of your jobs reaches level 20, 30, 40, 50, 60, 70 and 75.

## Living world

Towns and the field feel populated (`modules/goomba/lua/crowds.lua` and friends):

- **Ambient crowds:** player-looking adventurers fill every era town and the 17 conquest outposts — resting at Home Points, browsing the Auction House, loitering at shops, walking between them and emoting. Purely visual.
- **Field parties:** adventurer camps outside town that play like a real 75-era exp party — a puller pulls, a tank holds hate, a WHM cures, a RDM/BRD refreshes and debuffs, damage dealers build TP and close skillchains, the BLM magic-bursts, and they rest between pulls (and can wipe). They never take a monster near a player.
- **Chatter:** the crowd shouts and makes small talk (canned lines). Local AI chat (Ollama) is off on this server.

Defaults are in `modules/goomba/lua/crowds_config.lua` (crowd size, field parties on/off, disabled zones); in game, `!crowd` and `!crowd field` adjust them for the current run. The data in `crowds_data.lua` is generated from this server's own files by `tools/crowds/gen-crowds-data.sh` — re-run it after a `goomba update`. Ported from [xi-forever-offline](https://github.com/Hurami89/xi-forever-offline) (GPL v3); its autonomous bot-players (a custom C++ module) are not included.

## Quests

- **A Small `<nation>` Challenge** (`modules/goomba/lua/nation_ring_quest.lua`), for example *A Small Bastok Challenge*: an envoy beside the gate guard in Southern San d'Oria, Bastok Markets and Windurst Woods gives any citizen their nation's ring, whatever their race, for defeating 10 experience-giving monsters in each of the two areas outside the city.

## Auction House

- An optional bot keeps the Auction House stocked and buys what players list, so there is a market even when few people are online: `sudo goomba ahbot on`. See [auction-house.md](auction-house.md).

Other custom behaviour lives in `modules/goomba/` — see its `README.md` in the repository.
