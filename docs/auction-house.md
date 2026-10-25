# The Auction House bot

Goomba XI is meant to be played solo, so there are no other players to fill the Auction House. The bot does their part:

- **It sells.** About 7,100 Level 75 era items are kept in stock (3 of each, and 3 stacks of everything stackable), under the name **Goomba AH**. It tops them up every hour.
- **It buys.** Every 30 seconds it buys whatever players list, if the item is on its list and the asking price isn't above its own. The seller is paid the bot's price (not the asking price) through the delivery box, like a normal AH sale.

It is [ffxiahbot](https://github.com/AdamGagorik/ffxiahbot) by Adam Gagorik (version 7.0.1, which supports LandSandBoat), run as the `goomba-ahbot` service. It only touches the `auction_house` table; LandSandBoat's own trigger pays sellers.

## Turn it on

**Where: the game server (10.2.5.64).**

```bash
cd /opt/goomba-xi-server && sudo git pull
sudo goomba ahbot on
```

It installs the bot, builds the item list, fills the AH (about 26,000 listings, a minute or two) and starts the service. Check:

```bash
sudo goomba ahbot status
```

In game, any Auction House now has items in every category. List something you own: within about 30 seconds it shows as sold, and the gil arrives in your delivery box.

## The item list

`tools/ah-items.py` builds `/opt/goomba/ahbot/items.csv` for this server from the bot's own Level 75 era list (prices scraped from ffxiah.com):

| Rule | Why |
| --- | --- |
| Only items with an AH category and without the "no auction" flag | No Rare/Ex items on the AH |
| Materials used or made only by recipes of expansions turned off in `settings/main.lua` are left out | No Wings of the Goddess or Abyssea materials |
| A price is always more than an NPC pays for the item | Buying from the bot and selling to a vendor never makes gil |
| A price is capped below the cheapest NPC or guild shop price | Buying from a vendor and selling to the bot never makes gil |
| Anything in `ahbot/exclude.txt` is left out | Your own exceptions |

The prices are today's retail ones, which can differ from 2007's. Scale them all with `AHBOT_PRICE_MULTIPLIER`, or exclude items you think are wrong.

## Settings

In `/etc/goomba/goomba.conf` (commented-out defaults are at the end of the file):

| Setting | Default | Meaning |
| --- | --- | --- |
| `AHBOT_NAME` | `Goomba AH` | Name shown as seller and buyer (max 15 characters) |
| `AHBOT_STOCK_SINGLE` | `3` | Copies of each item kept for sale |
| `AHBOT_STOCK_STACKS` | `3` | Stacks of each stackable item kept for sale |
| `AHBOT_PRICE_MULTIPLIER` | `1.0` | Scales every price (`0.5` = half), still kept within the NPC limits |
| `AHBOT_TICK` | `30` | Seconds between buying player listings |
| `AHBOT_RESTOCK` | `3600` | Seconds between restocks |

After changing any of them, or `ahbot/exclude.txt`, or the expansions in `settings/main.lua`:

```bash
sudo goomba ahbot refresh
```

It rebuilds the list, replaces the bot's listings with the new prices and restarts the bot.

## Commands

| Command | Does |
| --- | --- |
| `sudo goomba ahbot on` | Install, build the list, fill the AH, start |
| `sudo goomba ahbot refresh` | Rebuild the list and re-list at the new prices |
| `sudo goomba ahbot status` | Service state, items on the list, listings for sale, player listings bought |
| `sudo goomba ahbot off` | Stop the bot; its listings stay up |
| `sudo goomba ahbot clear` | Stop the bot and remove its listings (price history stays) |

The bot starts and stops with the game (`sudo goomba restart game`), and `goomba status` shows it. Its log is `/opt/goomba/ahbot/ahbot.log` (errors only) and `goomba logs ahbot`.
