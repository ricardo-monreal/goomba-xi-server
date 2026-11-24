"""Builds modules/custom/lua/crowds_data.lua for the ambient crowds module (crowds.lua).

Reads only the server's own files:
  sql/item_equipment.sql, sql/item_weapon.sql   -> era outfits per job and level (model ids)
  data/zones/<zone>/npcs.yaml                   -> where the Home Points, Auction Counters and shops are
  navmeshes/<Zone>.nav                          -> every spot is checked to be walkable floor, away from walls

Usage (from C:\\FFXISOLO):  python build_crowds_data.py [--server C:\\ffxi-local\\server] [--out <file>] [--seed N]
Writes nothing else. Safe to run again: the output file is replaced.
"""
import argparse
import math
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from navcheck import NavMesh  # noqa: E402

# ---------------------------------------------------------------------------------------------------------------
# Areas with a crowd: every era town and every conquest outpost.
#   yaml folder name (data/zones/<name>) -> (kind, level weights)
#   kind: town (full crowd), small (smaller town, 60%), outpost (field outpost, 25% of the crowd size)
# Spots: Home Points -> resting, Auction Counters -> AH browsers, humanoid NPCs (shops, quest people) -> standing
# around; at outposts the conquest overseers (R.K./I.M./W.W.) -> resting and standing around.
# The San d'Oria starter cities are mostly low levels; Jeuno and the Aht Urhgan towns mostly high.
# ---------------------------------------------------------------------------------------------------------------
L_NATION = {10: 28, 20: 22, 30: 15, 40: 10, 50: 9, 60: 7, 70: 4, 75: 5}
L_JEUNO = {10: 3, 20: 12, 30: 15, 40: 15, 50: 15, 60: 12, 70: 10, 75: 18}
L_PORTS = {10: 35, 20: 45, 30: 15, 40: 5}
L_REMOTE = {30: 20, 40: 25, 50: 25, 60: 15, 70: 5, 75: 10}
L_COP = {40: 10, 50: 25, 60: 25, 70: 20, 75: 20}
L_TOAU = {40: 10, 50: 20, 60: 25, 70: 20, 75: 25}

ZONE_LIST = {
    # towns
    "southern_san_doria": ("town", L_NATION), "northern_san_doria": ("town", L_NATION), "port_san_doria": ("town", L_NATION),
    "bastok_mines": ("town", L_NATION), "bastok_markets": ("town", L_NATION), "port_bastok": ("town", L_NATION), "metalworks": ("small", L_NATION),
    "windurst_waters": ("town", L_NATION), "windurst_walls": ("town", L_NATION), "port_windurst": ("town", L_NATION), "windurst_woods": ("town", L_NATION),
    "rulude_gardens": ("town", L_JEUNO), "upper_jeuno": ("town", L_JEUNO), "lower_jeuno": ("town", L_JEUNO), "port_jeuno": ("town", L_JEUNO),
    "selbina": ("small", L_PORTS), "mhaura": ("small", L_PORTS),
    "rabao": ("small", L_REMOTE), "kazham": ("small", L_REMOTE), "norg": ("small", L_REMOTE),
    "tavnazian_safehold": ("town", L_COP),
    "aht_urhgan_whitegate": ("town", L_TOAU), "al_zahbi": ("small", L_TOAU), "nashmau": ("small", L_TOAU),
    # conquest outposts (levels: the people camping that region)
    "west_ronfaure": ("outpost", {10: 80, 20: 20}), "north_gustaberg": ("outpost", {10: 80, 20: 20}),
    "west_sarutabaruta": ("outpost", {10: 80, 20: 20}),
    "valkurm_dunes": ("outpost", {10: 30, 20: 60, 30: 10}), "buburimu_peninsula": ("outpost", {10: 20, 20: 60, 30: 20}),
    "jugner_forest": ("outpost", {10: 10, 20: 50, 30: 40}), "pashhow_marshlands": ("outpost", {20: 40, 30: 50, 40: 10}),
    "meriphataud_mountains": ("outpost", {20: 40, 30: 50, 40: 10}), "qufim_island": ("outpost", {20: 30, 30: 50, 40: 20}),
    "yuhtunga_jungle": ("outpost", {30: 40, 40: 40, 50: 20}), "yhoator_jungle": ("outpost", {30: 30, 40: 50, 50: 20}),
    "the_sanctuary_of_zitah": ("outpost", {30: 30, 40: 50, 50: 20}), "eastern_altepa_desert": ("outpost", {40: 40, 50: 50, 60: 10}),
    "lufaise_meadows": ("outpost", {40: 30, 50: 40, 60: 30}), "cape_teriggan": ("outpost", {50: 30, 60: 50, 70: 20}),
    "beaucedine_glacier": ("outpost", {50: 30, 60: 40, 70: 30}), "xarcabard": ("outpost", {60: 20, 70: 40, 75: 40}),
}
SCALE = {"town": 1.0, "small": 0.6, "outpost": 0.25}
MAX_IDLE_ANCHORS = 40         # humanoid NPCs used as "standing around" spots per town (spread out over the area)
# Only Southern San d'Oria keeps its hand-picked list (it was checked in game first)
IDLE_NAMES = {
    "southern_san_doria": r"^(Ailevia|Arpetion|Corua|Phamelise|Apairemant|Ferdoulemiont|Rosel|Carautia|Ashene|Valderotaux|Shilah|"
                          r"Lusiane|Ostalie|Raimbroy|Benaige|Aveline|Ambrotien|Faulpie|Hanaa Punaa|Kueh Igunahmori)$",
}
NOT_IDLE = re.compile(r"^(Door|Gate|Moogle|.*Moogle|\?\?\?|Home Point|Auction Counter|Survival Guide|Chocobo|Treasure|Planar|"
                      r"Ephemeral|Repairer|Artisan|Erudite|Agent|Voidwatch|Geomagnetic|Waypoint)", re.I)
OUTPOST_NAME = re.compile(r", (R\.K\.|I\.M\.|W\.W\.)'?$")


BRACKETS = [10, 20, 30, 40, 50, 60, 70, 75]
OUTFITS_PER = 8
# Equipment slot bits (item_equipment.slot) and the look's slot nibble (squad.cpp / garrison looks use the same)
SLOT_BITS = {"main": 0x01, "sub": 0x02, "ranged": 0x04, "head": 0x10, "body": 0x20, "hands": 0x40, "legs": 0x80, "feet": 0x100}
LOOK_ORDER = [("head", 0x1000), ("body", 0x2000), ("hands", 0x3000), ("legs", 0x4000), ("feet", 0x5000),
              ("main", 0x6000), ("sub", 0x7000), ("ranged", 0x8000)]
# Era item id ranges (same as the AH simulator's era filter, ah_sim.json)
ARMOR_IDS = (12000, 15999)
WEAPON_IDS = (16000, 18199)

JOBS = ["WAR", "MNK", "WHM", "BLM", "RDM", "THF", "PLD", "DRK", "BST", "BRD", "RNG", "SAM", "NIN", "DRG", "SMN", "BLU", "COR", "PUP"]
# Weapon skills (item_weapon.skill): 1 H2H 2 dagger 3 sword 4 great sword 5 axe 6 great axe 7 scythe 8 polearm
# 9 katana 10 great katana 11 club 12 staff 25 archery 26 marksmanship
MAIN_SKILLS = {
    "WAR": [6, 5, 4], "MNK": [1], "WHM": [11, 12], "BLM": [12, 11], "RDM": [3, 2], "THF": [2], "PLD": [3, 11],
    "DRK": [7, 4], "BST": [5], "BRD": [2], "RNG": [2, 5], "SAM": [10], "NIN": [9], "DRG": [8], "SMN": [12],
    "BLU": [3], "COR": [3, 2], "PUP": [1],
}
SHIELD_JOBS = {"WAR", "WHM", "RDM", "PLD", "BLU", "BRD"}
RANGED_SKILLS = {"RNG": [25, 26], "COR": [26]}
TWO_HANDED = {1, 4, 6, 7, 8, 10, 12}
# Event costumes and later-era campaign sets that share the era id ranges
DENY_NAMES = re.compile(r"^(dream_|horror|pumpkin|trick|treat|witch|moogle|kupo|fourth_|cobra_|iron_ram|lion_|"
                        r"chocobo_shirt|tidal_|rabbit|hume_|elvaan_|tarutaru_|mithra_|galka_|gm_|sprout|seasonal|celebratory|wedding)"
                        r"|taru\.|elv\.|mithran|galkan|_trunks|_shorts|_maillot|_top$|_gilet|_[mf]_|_[mf]$|wivre")   # race- or gender-locked outfits
AH_SHARE = 0.85   # most players wear gear from the auction house; the rest is quest, NM or crafted rare gear


def sql_rows(path, table):
    rows = []
    prefix = "INSERT INTO `%s` VALUES (" % table
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.startswith(prefix):
                continue
            body = line[len(prefix):].split(");", 1)[0]  # (lines can end with a "-- comment")
            rows.append([p.strip("'") for p in re.findall(r"'(?:[^'\\]|\\.)*'|[^,]+", body)])
    return rows


def ah_items(server):
    """Item ids the auction house lists (item_basic.aH > 0)."""
    out = set()
    for r in sql_rows(os.path.join(server, "sql", "item_basic.sql"), "item_basic"):
        try:
            if r[8].strip() not in ("0", "@NONE"):   # the dump writes categories as @NAMES
                out.add(int(r[0]))
        except (ValueError, IndexError):
            pass
    return out


def load_gear(server):
    """{slot: [(itemid, name, level, jobs, model, covers)]} for era gear (armor 12000-15999, weapons 16000-18199, level <= 75)."""
    weapons = {int(r[0]): int(r[2]) for r in sql_rows(os.path.join(server, "sql", "item_weapon.sql"), "item_weapon")}
    listed = ah_items(server)
    gear = {k: [] for k in SLOT_BITS}
    for r in sql_rows(os.path.join(server, "sql", "item_equipment.sql"), "item_equipment"):
        itemid, name, level, ilevel, jobs, model, slot, rslot = int(r[0]), r[1], int(r[2]), int(r[3]), int(r[4]), int(r[5]), int(r[8]), int(r[9])
        su_level = int(r[11]) if len(r) > 11 else 0
        if model == 0 or level > 75 or ilevel > 0 or su_level > 0 or model > 0x0FFF:
            continue
        in_armor = ARMOR_IDS[0] <= itemid <= ARMOR_IDS[1]
        in_weapon = WEAPON_IDS[0] <= itemid <= WEAPON_IDS[1]
        if not (in_armor or in_weapon):
            continue
        njobs = bin(jobs & 0x3FFFF).count("1")
        if jobs & 0x3FFFF == 0 or DENY_NAMES.search(name):
            continue
        if level <= 1 and njobs >= 18 and slot & (SLOT_BITS["body"] | SLOT_BITS["head"]):
            continue  # costumes and event clothes (level 1, every job)
        for sname, bit in SLOT_BITS.items():
            if slot & bit:
                gear[sname].append({"id": itemid, "name": name, "level": level, "jobs": jobs, "model": model,
                                    "covers": rslot, "skill": weapons.get(itemid, 0), "slot": slot, "ah": itemid in listed})
    return gear


def pick(rng, items, job_bit, level, low_span=14):
    """A random item for this job, close below the level (falls back to anything wearable at the level)."""
    near = [i for i in items if i["jobs"] & job_bit and level - low_span <= i["level"] <= level]
    if near:
        common = [i for i in near if i["ah"]]
        if common and rng.random() < AH_SHARE:
            return rng.choice(common)
        return rng.choice(near)
    wearable = [i for i in items if i["jobs"] & job_bit and i["level"] <= level]
    if wearable:
        top = max(i["level"] for i in wearable)
        return rng.choice([i for i in wearable if i["level"] >= top - 5])
    return None


def outfit(rng, gear, job, level):
    jid = JOBS.index(job)
    bit = 1 << jid
    look = {}
    covered = 0
    for sname in ("body", "head", "hands", "legs", "feet"):
        if (covered & SLOT_BITS[sname]) or rng.random() < (0.15 if sname == "head" else 0.04):
            continue  # some players hide their head piece or skip a slot
        item = pick(rng, gear[sname], bit, level)
        if item:
            look[sname] = item["model"]
            covered |= item["covers"]
    for sname in list(look):
        if covered & SLOT_BITS[sname] and sname != "body":
            del look[sname]
    skills = MAIN_SKILLS[job]
    skill = skills[0] if rng.random() < 0.7 else rng.choice(skills)
    mains = [i for i in gear["main"] if i["skill"] == skill]
    main = pick(rng, mains, bit, level)
    if main:
        look["main"] = main["model"]
        two_handed = main["skill"] in TWO_HANDED or main["slot"] == SLOT_BITS["main"]
        if not two_handed:
            if job == "NIN":
                sub = pick(rng, [i for i in gear["sub"] if i["skill"] == 9], bit, level)
            elif job in SHIELD_JOBS and rng.random() < 0.8:
                sub = pick(rng, [i for i in gear["sub"] if i["skill"] == 0 and i["slot"] == SLOT_BITS["sub"]], bit, level)
            else:
                sub = None
            if sub:
                look["sub"] = sub["model"]
    if job in RANGED_SKILLS:
        ranged = pick(rng, [i for i in gear["ranged"] if i["skill"] in RANGED_SKILLS[job]], bit, level)
        if ranged:
            look["ranged"] = ranged["model"]
    # 8 slots as 4 hex digits each, little-endian, with the slot nibble (the server's stringToLook strips it again)
    out = ""
    for sname, base in LOOK_ORDER:
        value = base + look[sname] if sname in look else 0
        out += "%02X%02X" % (value & 0xFF, value >> 8)
    return out


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def zone_names(server):
    """yaml folder -> (zone id, script/navmesh name)"""
    return zone_names_for(server, ZONE_LIST)


def zone_names_for(server, folders):
    scripts = {norm(d): d for d in os.listdir(os.path.join(server, "scripts", "zones"))}
    out = {}
    for folder in folders:
        p = os.path.join(server, "data", "zones", folder, "npcs.yaml")
        if not os.path.exists(p):
            continue
        first = re.search(r"\n  (\d+):\n", open(p, encoding="utf-8").read())
        script = scripts.get(norm(folder))
        if first and script:
            out[folder] = ((int(first.group(1)) >> 12) & 0x1FF, script)
    return out


def read_anchors(server, folder, kind):
    text = open(os.path.join(server, "data", "zones", folder, "npcs.yaml"), encoding="utf-8").read()
    idle_names = re.compile(IDLE_NAMES[folder]) if folder in IDLE_NAMES else None
    anchors, idle_pool, seen = [], [], set()
    for block in re.split(r"\n  \d+:\n", text)[1:]:
        name = re.search(r"display_name:\s*(.*)", block)
        at = re.search(r"at:\s*\[([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)", block)
        status = re.search(r"status:\s*(\S+)", block)
        if not name or not at:
            continue
        name = name.group(1).strip().strip("'")
        pos = tuple(float(v) for v in at.groups())
        st = status.group(1) if status else ""
        if kind == "outpost":
            if OUTPOST_NAME.search(name):
                key = (round(pos[0]), round(pos[2]))
                if key not in seen:          # the three nations' overseers share one spot
                    seen.add(key)
                    anchors.append(("rest", name, pos))
                    anchors.append(("idle", name, pos))
            continue
        if re.match(r"^Home Point #\d+$", name):
            anchors.append(("rest", name, pos))
        elif name == "Auction Counter" and st == "normal":
            anchors.append(("ah", name, pos))
        elif st != "normal" or NOT_IDLE.search(name):
            continue
        elif idle_names is not None:
            if idle_names.search(name):
                anchors.append(("idle", name, pos))
        elif re.search(r"type:\s*equipped", block) or re.search(r"race:\s*\d", block):
            idle_pool.append(("idle", name, pos))
    # spread the standing-around anchors over the whole area (farthest point first)
    if idle_pool:
        picked = [idle_pool[0]]
        rest = idle_pool[1:]
        while rest and len(picked) < MAX_IDLE_ANCHORS:
            best = max(rest, key=lambda a: min((a[2][0] - p[2][0]) ** 2 + (a[2][2] - p[2][2]) ** 2 for p in picked))
            picked.append(best)
            rest.remove(best)
        anchors += picked
    return anchors


RADII = {
    "town":    {"rest": (1.8, 4.5, 6), "ah": (1.4, 3.0, 4), "idle": (2.0, 5.0, 2)},
    "small":   {"rest": (1.8, 4.5, 5), "ah": (1.4, 3.0, 4), "idle": (2.0, 5.0, 2)},
    "outpost": {"rest": (2.0, 6.0, 5), "ah": (1.4, 3.0, 4), "idle": (2.5, 7.0, 5)},
}
RADII["southern_san_doria"] = {"rest": (1.8, 4.5, 6), "ah": (1.4, 3.0, 4), "idle": (2.0, 5.0, 3)}


def spots_for_zone(server, folder, script, kind):
    nav = NavMesh(os.path.join(server, "navmeshes", script + ".nav"))
    anchors = read_anchors(server, folder, kind)
    spots = []
    rejected = 0
    rng = random.Random(script)          # (same seed as the first version, so Southern San d'Oria keeps its spots)
    radii = RADII.get(folder, RADII[kind])
    for akind, name, (ax, ay, az) in anchors:
        rmin, rmax, want = radii[akind]
        got = 0
        for _ in range(80):
            if got >= want:
                break
            a = rng.random() * 2 * math.pi
            r = rmin + rng.random() * (rmax - rmin)
            x, z = ax + r * math.cos(a), az + r * math.sin(a)
            h = nav.clear(x, ay, z, radius=0.9)
            if h is None or abs(h - ay) > 1.5:
                rejected += 1
                continue
            if any((s["x"] - x) ** 2 + (s["z"] - z) ** 2 < 1.6 ** 2 for s in spots):
                continue
            # face the anchor (FFXI rotation: 0-255, 0 = east; same formula as the server's getWorldAngle)
            rot = int(round((math.atan2(-(az - z), ax - x) % (2 * math.pi)) / (2 * math.pi) * 256)) % 256
            spots.append({"kind": akind, "x": round(x, 3), "y": round(h + 0.2, 3), "z": round(z, 3), "rot": rot, "near": name})
            got += 1
    return anchors, spots, rejected


CRAFTS = ["Wood", "Smith", "Gold", "Cloth", "Leather", "Bone", "Alchemy", "Cook"]
ERA_TAGS = {"NULL", "ROTZ", "COP", "TOAU"}


def sell_list(server, kit, limit=400):
    """Crafted era items that players would shout about: (name, price, craft level). Prices from the AH simulator's
    market data (ah_prices.json in the kit) when known, else the vendor price x 4 (the AH simulator's default)."""
    prices = {}
    try:
        import json
        with open(os.path.join(kit, "ah_prices.json"), encoding="utf-8-sig") as f:
            for k, v in json.load(f).get("items", {}).items():
                if v and v[0]:
                    prices[int(k)] = int(v[0])
    except (OSError, ValueError):
        pass
    basesell = {}
    for r in sql_rows(os.path.join(server, "sql", "item_basic.sql"), "item_basic"):
        try:
            basesell[int(r[0])] = int(r[-1])
        except (ValueError, IndexError):
            pass
    seen, out = set(), []
    pattern = re.compile(r"^INSERT INTO `synth_recipes` VALUES \((.*)\);")
    with open(os.path.join(server, "sql", "synth_recipes.sql"), encoding="utf-8", errors="replace") as f:
        for line in f:
            m = pattern.match(line.strip())
            if not m:
                continue
            parts = [p.strip("'") for p in re.findall(r"'(?:[^'\\]|\\.)*'|[^,]+", m.group(1))]
            try:
                desynth, skills, result, name, tag = int(parts[1]), [int(x) for x in parts[3:11]], int(parts[21]), parts[29], parts[30]
            except (ValueError, IndexError):
                continue
            if desynth or tag.upper() not in ERA_TAGS or result in seen or not re.match(r"^[A-Za-z][A-Za-z' +-]{2,22}$", name):
                continue
            if not (result <= 5800 or 12000 <= result <= 18199):
                continue
            price = prices.get(result) or basesell.get(result, 0) * 4
            if price < 200:
                continue
            seen.add(result)
            out.append((name, price, max(skills)))
    random.Random(7).shuffle(out)
    return sorted(out[:limit], key=lambda x: x[2])


# ---------------------------------------------------------------------------------------------------------------
# Field parties (phase 3): weapon skills each job has at each level (as monster skills, so a bot can use them),
# the spells the party roles cast, and the field areas they camp in.
# ---------------------------------------------------------------------------------------------------------------
FIELD_ZONES = [
    "valkurm_dunes", "konschtat_highlands", "tahrongi_canyon", "la_theine_plateau", "gusgen_mines",
    "qufim_island", "jugner_forest", "korroloka_tunnel", "yuhtunga_jungle", "buburimu_peninsula", "bibiki_bay",
    "crawlers_nest", "yhoator_jungle", "beadeaux", "davoi", "sauromugue_champaign", "garlaige_citadel", "castle_oztroja",
    "eastern_altepa_desert", "sea_serpent_grotto", "the_eldieme_necropolis", "labyrinth_of_onzozo", "kuftal_tunnel",
    "gustav_tunnel", "the_boyahda_tree", "ifrits_cauldron", "aydeewa_subterrane", "ro_maeve", "mamook", "caedarva_mire",
    "valley_of_sorrows", "den_of_rancor", "mount_zhayolm", "bhaflau_thickets", "uleguerand_range", "wajaom_woodlands",
    "arrapago_reef", "halvung",
]
# The weapons each job's bots fight with (players swapped weapons for skillchains, e.g. a WAR with an axe)
JOB_WS_SKILL = {"WAR": ["great_axe", "axe", "sword"], "MNK": ["hand_to_hand", "staff"], "WHM": ["club"], "BLM": ["staff"],
                "RDM": ["sword", "dagger"], "THF": ["dagger"], "PLD": ["sword", "club"], "DRK": ["scythe", "great_sword"],
                "BST": ["axe"], "BRD": ["dagger"], "RNG": ["dagger", "axe"], "SAM": ["great_katana", "polearm"],
                "NIN": ["katana", "dagger"], "DRG": ["polearm"], "SMN": ["staff"], "BLU": ["sword", "club"],
                "COR": ["sword", "dagger"], "PUP": ["hand_to_hand"]}
FIELD_SPELLS = ["cure", "cure_ii", "cure_iii", "cure_iv", "dia", "dia_ii", "paralyze", "slow", "protect", "protect_ii",
                "protect_iii", "shell", "shell_ii", "flash", "refresh", "haste", "sleep", "sleep_ii", "foe_lullaby",
                "mages_ballad", "mages_ballad_ii", "valor_minuet", "valor_minuet_ii", "valor_minuet_iii", "valor_minuet_iv",
                "utsusemi_ichi", "utsusemi_ni", "banish", "banish_ii"]
for _e in ("stone", "water", "aero", "fire", "blizzard", "thunder"):
    FIELD_SPELLS += [_e, _e + "_ii", _e + "_iii", _e + "_iv"]


def mini_yaml_blocks(path, top):
    """name -> {key: raw value} for the 2-space entries under a top-level key (enough for weapon_skills.yaml)."""
    out, cur, inside = {}, None, False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if re.match(r"^\S", line):
                inside = line.startswith(top + ":")
                continue
            if not inside:
                continue
            m = re.match(r"^  ([a-z0-9_]+):\s*$", line)
            if m:
                cur = out.setdefault(m.group(1), {})
                continue
            m = re.match(r"^    ([a-z_]+):\s*(.*?)\s*(#.*)?$", line)
            if m and cur is not None:
                cur[m.group(1)] = m.group(2)
    return out


def skill_caps(path):
    ranks, caps, part = {}, {}, None
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("ranks:"):
                part = "ranks"
                continue
            if line.strip().startswith("caps:"):
                part = "caps"
                continue
            m = re.match(r"^\s+([a-z_0-9]+):\s*\{(.*)\}", line)
            if not m:
                continue
            pairs = dict((k.strip(), v.strip()) for k, v in (x.split(":") for x in m.group(2).split(",") if ":" in x))
            if part == "ranks":
                ranks[m.group(1)] = pairs
            elif part == "caps":
                caps[int(m.group(1))] = {k: int(v) for k, v in pairs.items()}
    return ranks, caps


def field_data(server):
    ws = mini_yaml_blocks(os.path.join(server, "data", "weapon_skills.yaml"), "weapon_skills")
    ranks, caps = skill_caps(os.path.join(server, "data", "skills.yaml"))
    mobskill = {}
    for r in sql_rows(os.path.join(server, "sql", "mob_skills.sql"), "mob_skills"):
        try:
            sid, name = int(r[0]), r[2]
        except (ValueError, IndexError):
            continue
        if name not in mobskill or sid < mobskill[name]:
            mobskill[name] = sid
    per_job = {}
    for job, skills in JOB_WS_SKILL.items():
        lst = []
        for name, e in ws.items():
            skill = e.get("skill")
            rank = ranks.get(skill, {}).get(job.lower())
            if skill not in skills or "level" not in e or "unlock" in e or name not in mobskill:
                continue
            jobs = [j.strip() for j in e.get("jobs", "").strip("[]").split(",")]
            if job.lower() not in jobs or not rank:
                continue
            need = int(e["level"])
            lvl = next((L for L in range(1, 76) if caps.get(L, {}).get(rank, 0) >= need), None)
            if lvl is None:
                continue
            sc = [x.strip() for x in e.get("skillchain", "").strip("[]").split(",") if x.strip()]
            lst.append((lvl, mobskill[name], name.replace("_", " ").title(), sc))
        per_job[job] = sorted(lst)
    spells = {}
    pattern = re.compile(r"^INSERT INTO `spell_list` VALUES \((\d+),'([a-z_]+)',0x([0-9A-Fa-f]+),")
    with open(os.path.join(server, "sql", "spell_list.sql"), encoding="utf-8", errors="replace") as f:
        for line in f:
            m = pattern.match(line)
            if not m or m.group(2) not in FIELD_SPELLS:
                continue
            levels = bytes.fromhex(m.group(3))[:18]
            spells[m.group(2)] = (int(m.group(1)), {JOBS[i]: v for i, v in enumerate(levels) if 0 < v <= 75})
    return per_job, spells


def lua_quote(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--server", default=r"C:\ffxi-local\server")
    ap.add_argument("--out", default=None)
    ap.add_argument("--seed", type=int, default=75)
    ap.add_argument("--kit", default=os.path.dirname(HERE))
    args = ap.parse_args()
    out_path = args.out or os.path.join(args.server, "modules", "custom", "lua", "crowds_data.lua")

    rng = random.Random(args.seed)
    gear = load_gear(args.server)
    lines = ["-- Generated by build_crowds_data.py from the server's own item tables, npcs.yaml and navmeshes.",
             "-- Do not edit by hand: run the script again instead. Read by modules/custom/lua/crowds.lua.",
             "local d = {}", "", "d.jobs = { " + ", ".join(lua_quote(j) for j in JOBS) + " }", "",
             "-- d.outfits[job][bracket] = list of 32-hex-digit gear looks (head body hands legs feet main sub ranged)",
             "d.outfits = {}"]
    count = 0
    for job in JOBS:
        lines.append("d.outfits.%s = {" % job)
        for b in BRACKETS:
            looks = sorted({outfit(rng, gear, job, b) for _ in range(OUTFITS_PER * 2)})[:OUTFITS_PER]
            count += len(looks)
            lines.append("    [%d] = { %s }," % (b, ", ".join(lua_quote(x) for x in looks)))
        lines.append("}")
    lines += ["", "d.zones = {}"]
    report = []
    names = zone_names(args.server)
    for folder, (kind, levels) in ZONE_LIST.items():
        if folder not in names:
            report.append("%s: SKIPPED (no npcs.yaml or zone script found)" % folder)
            continue
        zid, script = names[folder]
        if not os.path.exists(os.path.join(args.server, "navmeshes", script + ".nav")):
            report.append("%s: SKIPPED (no navmesh %s.nav)" % (script, script))
            continue
        anchors, spots, rejected = spots_for_zone(args.server, folder, script, kind)
        if not spots:
            report.append("%s: SKIPPED (no walkable spots found)" % script)
            continue
        lines.append("d.zones[%d] = {" % zid)
        lines.append("    name   = %s," % lua_quote(script))
        lines.append("    scale  = %.2f," % SCALE[kind])
        lines.append("    levels = { %s }," % ", ".join("[%d] = %d" % kv for kv in sorted(levels.items())))
        lines.append("    spots  = {")
        for s in spots:
            lines.append("        { kind = '%s', x = %.3f, y = %.3f, z = %.3f, rot = %d }, -- %s" % (s["kind"], s["x"], s["y"], s["z"], s["rot"], s["near"]))
        lines.append("    },")
        lines.append("}")
        kinds = {}
        for s in spots:
            kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
        report.append("%-24s %3d: %-7s %3d anchors, %3d spots %s" % (script, zid, kind, len(anchors), len(spots), kinds))
    per_job, spells = field_data(args.server)
    lines += ["", "-- Field parties: weapon skills by job { level, monster-skill id, name, { skillchain properties } }", "d.ws = {}"]
    for job in JOBS:
        lines.append("d.ws.%s = {" % job)
        for lvl, sid, name, sc in per_job.get(job, []):
            lines.append("    { %d, %d, %s, { %s } }," % (lvl, sid, lua_quote(name), ", ".join(lua_quote(x) for x in sc)))
        lines.append("}")
    lines += ["", "-- Field parties: spells { id, { job = level } }", "d.spells = {"]
    for name in sorted(spells):
        sid, lv = spells[name]
        lines.append("    %s = { %d, { %s } }," % (name, sid, ", ".join("%s = %d" % kv for kv in sorted(lv.items()))))
    lines.append("}")
    names = zone_names_for(args.server, FIELD_ZONES)
    lines += ["", "-- Field parties: areas where parties camp (zone id = name)", "d.field = {"]
    nfield = 0
    for folder in FIELD_ZONES:
        if folder in names and os.path.exists(os.path.join(args.server, "navmeshes", names[folder][1] + ".nav")):
            lines.append("    [%d] = %s," % (names[folder][0], lua_quote(names[folder][1])))
            nfield += 1
    lines.append("}")
    report.append("Field parties: %d areas, weapon skills for %d jobs, %d spells" % (nfield, len(per_job), len(spells)))
    sells = sell_list(args.server, args.kit)
    lines += ["", "-- crafted era items for 'selling' shouts: { name, price in gil, craft level }", "d.sell = {"]
    for name, price, lvl in sells:
        lines.append("    { %s, %d, %d }," % (lua_quote(name), price, lvl))
    lines.append("}")
    report.append("Selling list: %d crafted era items" % len(sells))
    lines += ["", "return d", ""]
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("Wrote %s" % out_path)
    print("Outfits: %d (18 jobs x %d level brackets)" % (count, len(BRACKETS)))
    for line in report:
        print(line)


if __name__ == "__main__":
    main()
