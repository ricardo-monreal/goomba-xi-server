#!/usr/bin/env python3
"""Builds the Auction House bot's item list (items.csv for ffxiahbot) for Goomba XI.

Starts from ffxiahbot's Level 75 era price list (bin/items75.csv: about 7,400 items, prices
scraped from ffxiah.com, later-era items already removed by its author) and keeps only what fits
this server:

  * Auctionable: the item has an AH category and no "no auction" flag (so no Rare/Ex items).
  * In the era: materials used or made only by recipes of expansions turned off in
    settings/main.lua are dropped, as is anything listed in --exclude.
  * No free gil: a price is raised to more than an NPC pays for the item (so buying from the bot
    and selling to a vendor never profits) and capped below the cheapest NPC or guild shop price
    (so buying from a vendor and selling to the bot never profits). Items where those can't both
    hold are left out.

    python3 tools/ah-items.py --lsb /opt/goomba/server --prices <ffxiahbot bin/items75.csv> \
        --items <item_basic.tsv> --settings settings/main.lua [--exclude ahbot/exclude.txt] --out items.csv

item_basic.tsv: `mysql -N -B xidb -e "SELECT itemid, stackSize, flags, aH, BaseSell, name FROM item_basic"`.
"""

import argparse
import csv
import pathlib
import re
import sys

NO_AUCTION = 0x40
# content_tag values in synth_recipes and the settings that enable them.
TAG_SETTING = {
    "ROTZ": "ENABLE_ROTZ", "COP": "ENABLE_COP", "TOAU": "ENABLE_TOAU", "WOTG": "ENABLE_WOTG",
    "ACP": "ENABLE_ACP", "AMK": "ENABLE_AMK", "ASA": "ENABLE_ASA", "ABYSSEA": "ENABLE_ABYSSEA",
    "SOA": "ENABLE_SOA", "ROV": "ENABLE_ROV", "TVR": "ENABLE_TVR", "VOIDWATCH": "ENABLE_VOIDWATCH",
}
# NPC prices drop a little with fame; stay this far under the listed price.
NPC_MARGIN = 0.9


def enabled_tags(settings_file: pathlib.Path) -> set[str]:
    text = settings_file.read_text(encoding="utf-8")
    on = {None}
    for tag, key in TAG_SETTING.items():
        m = re.search(rf"^\s*{key}\s*=\s*(\d+)", text, re.M)
        if m and int(m.group(1)):
            on.add(tag)
    return on


def recipe_tags(lsb: pathlib.Path) -> dict[int, set]:
    """item id -> content tags of every recipe that uses or makes it."""
    tags: dict[int, set] = {}
    row = re.compile(r"^INSERT INTO `synth_recipes` VALUES \((.*)\);\s*$")
    for line in (lsb / "sql" / "synth_recipes.sql").open(encoding="utf-8"):
        m = row.match(line)
        if not m:
            continue
        parts = next(csv.reader([m.group(1)], quotechar="'", escapechar="\\", skipinitialspace=True))
        tag = None if parts[30].strip() == "NULL" else parts[30].strip()
        for i in list(range(11, 21)) + list(range(21, 25)):
            iid = int(parts[i])
            if iid:
                tags.setdefault(iid, set()).add(tag)
    return tags


def item_enum(lsb: pathlib.Path) -> dict[str, int]:
    names = {}
    for line in (lsb / "scripts" / "enum" / "item.lua").open(encoding="utf-8"):
        m = re.match(r"^\s*([A-Z0-9_]+)\s*=\s*(\d+)", line)
        if m:
            names[m.group(1)] = int(m.group(2))
    return names


def npc_prices(lsb: pathlib.Path, names: dict[str, int]) -> dict[int, int]:
    """Lowest price any NPC or guild shop sells each item for."""
    low: dict[int, int] = {}

    def note(name: str, price: int) -> None:
        iid = names.get(name)
        if iid and price > 0:
            low[iid] = min(price, low.get(iid, price))

    shop = re.compile(r"\{\s*xi\.item\.([A-Z0-9_]+)\s*,\s*(\d+)")
    files = list((lsb / "scripts" / "zones").glob("*/npcs/*.lua")) + [lsb / "scripts" / "globals" / "shop.lua"]
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        if "shop" not in text.lower():
            continue
        for name, price in shop.findall(text):
            note(name, int(price))
    guild = re.compile(r"id\s*=\s*xi\.item\.([A-Z0-9_]+).*?buyMax\s*=\s*(\d+)")
    gfile = lsb / "scripts" / "data" / "guild_shops.lua"
    if gfile.exists():
        for name, buy_max in guild.findall(gfile.read_text(encoding="utf-8")):
            note(name, int(buy_max) // 10)  # a full shelf sells at a tenth of buyMax
    return low


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lsb", required=True, type=pathlib.Path)
    ap.add_argument("--exclude", type=pathlib.Path, help="file with item ids to leave out (one per line, # comments)")
    ap.add_argument("--prices", required=True, type=pathlib.Path)
    ap.add_argument("--items", required=True, type=pathlib.Path)
    ap.add_argument("--settings", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--stock-single", type=int, default=3)
    ap.add_argument("--stock-stacks", type=int, default=3)
    ap.add_argument("--price-multiplier", type=float, default=1.0)
    a = ap.parse_args()

    tags_on = enabled_tags(a.settings)
    excluded = set()
    if a.exclude and a.exclude.exists():
        for line in a.exclude.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if line.isdigit():
                excluded.add(int(line))
    rtags = recipe_tags(a.lsb)
    npc = npc_prices(a.lsb, item_enum(a.lsb))

    basic = {}
    for line in a.items.open(encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if len(f) >= 5:
            basic[int(f[0])] = (int(f[1]), int(f[2]), int(f[3]), int(f[4]), f[5] if len(f) > 5 else "")

    prices = {}
    with a.prices.open(encoding="utf-8") as fh:
        r = csv.reader(fh)
        head = [h.strip() for h in next(r)]
        for row in r:
            d = dict(zip(head, (x.strip() for x in row)))
            prices[int(d["itemid"])] = (int(d["price_single"]), int(d["price_stacks"]))

    why: dict[str, int] = {}
    out = []
    for iid, (p_single, p_stacks) in sorted(prices.items()):
        def skip(reason: str) -> None:
            why[reason] = why.get(reason, 0) + 1

        if iid not in basic:
            skip("not in this server's item list"); continue
        stack_size, flags, ah, base_sell, name = basic[iid]
        if ah == 0 or flags & NO_AUCTION:
            skip("not auctionable (no AH category, or Rare/Ex)"); continue
        if iid in excluded:
            skip("in the exclude list"); continue
        if iid < 4096 and iid in rtags and not (rtags[iid] & tags_on):
            skip("material only used by later expansions"); continue

        cap = int(npc[iid] * NPC_MARGIN) if iid in npc else None
        single = max(int(p_single * a.price_multiplier), base_sell + 1)
        if cap is not None and single > cap:
            single = cap
        if single <= base_sell or single <= 1:
            skip("an NPC sells it cheaper than it sells back (no safe price)"); continue

        sell_stacks = 0
        stack_price = 1
        if stack_size > 1:
            stack_price = int(p_stacks * a.price_multiplier) if p_stacks > 1 else single * stack_size
            stack_price = max(stack_price, base_sell * stack_size + 1)
            if cap is not None:
                stack_price = min(stack_price, cap * stack_size)
            if stack_price > base_sell * stack_size:
                sell_stacks = 1

        out.append([iid, name or f"item_{iid}", 1, 1, single, a.stock_single,
                    sell_stacks, sell_stacks, stack_price, a.stock_stacks if sell_stacks else 0])

    with a.out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["itemid", "name", "sell_single", "buy_single", "price_single", "stock_single",
                    "sell_stacks", "buy_stacks", "price_stacks", "stock_stacks"])
        w.writerows(out)

    print(f"ah-items: {len(out)} items written to {a.out} (expansions on: {', '.join(sorted(t for t in tags_on if t)) or 'base game only'})")
    for reason, n in sorted(why.items(), key=lambda x: -x[1]):
        print(f"  left out {n:5d}: {reason}")


if __name__ == "__main__":
    main()
