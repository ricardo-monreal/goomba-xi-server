-----------------------------------
-- GOOMBA XI: MAIN SETTINGS
-----------------------------------
-- Only the keys Goomba XI changes live here. Everything else comes from
-- LandSandBoat's settings/default/main.lua (LandSandBoat fills in any key that
-- is missing from this file).
--
-- Era: Level 75 cap, before Wings of the Goddess (late 2007). LandSandBoat's
-- era modules (GOOMBA_ERA_MODULES in /etc/goomba/goomba.conf) revert later
-- changes for every expansion turned off below, and the launcher ships the
-- matching client text (Era-DATs). For today's retail game instead: turn the
-- expansions and systems below back on, raise MAX_LEVEL to 99 and set
-- GOOMBA_ERA_MODULES="" (and drop "era" from the launcher's requiredOverlays).
-----------------------------------

xi = xi or {}
xi.settings = xi.settings or {}

xi.settings.main =
{
    SERVER_NAME = 'Goomba',

    SERVER_MESSAGE =
        'Welcome to Goomba XI!\n' ..
        'News, rules and your characters are on the Goomba XI website.',

    -- Lock content to the enabled expansions (uses the content_tag columns).
    RESTRICT_CONTENT = 1,

    -- Expansions: the original game, Zilart, Promathia and Aht Urhgan.
    -- Era-DATs expects WotG, Abyssea and Voidwatch to be off. If you change these,
    -- change the era/sql/<expansion> entries in GOOMBA_ERA_MODULES to match.
    ENABLE_ROTZ      = 1,
    ENABLE_COP       = 1,
    ENABLE_TOAU      = 1,
    ENABLE_WOTG      = 0,
    ENABLE_ACP       = 0,
    ENABLE_AMK       = 0,
    ENABLE_ASA       = 0,
    ENABLE_ABYSSEA   = 0,
    ENABLE_SOA       = 0,
    ENABLE_ROV       = 0,
    ENABLE_TVR       = 0,
    ENABLE_VOIDWATCH = 0,

    -- Later-era systems.
    ENABLE_MOG_HOUSE_2F   = 0,
    ENABLE_MOG_GARDEN     = 0,
    ENABLE_FIELD_MANUALS  = 0,
    ENABLE_GROUNDS_TOMES  = 0,
    ENABLE_SURVIVAL_GUIDE = 0,
    ENABLE_DAILY_TALLY    = 0,
    ENABLE_ROE            = 0,
    ENABLE_ROE_TIMED      = 0,
    ENABLE_MAGIAN_TRIALS  = 0,
    ENABLE_VOIDWALKER     = 0,
    ENABLE_MONSTROSITY    = 0,
    -- Trusts on: Goomba XI is played solo or in small groups with trusts as party members.
    -- Limits and the starter party are in modules/goomba/lua/solo_trusts.lua.
    ENABLE_TRUST_CASTING  = 1,
    ENABLE_TRUST_QUESTS   = 1,
    HOMEPOINT_TELEPORT    = 0,

    -- Level 75 cap, unlocked through Maat's Limit Break quests as in era.
    INITIAL_LEVEL_CAP = 50,
    MAX_LEVEL         = 75,

    -- Rates. EXP from kills is map.lua's EXP_RATE; this one covers EXP given by scripts
    -- (quest rewards, EXP scrolls). Keep the two equal.
    EXP_RATE  = 3.000,
    START_GIL = 10,
    ALL_MAPS  = 0,
}
