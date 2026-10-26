-----------------------------------
-- GOOMBA XI: MAP SETTINGS
-----------------------------------
-- Only the keys Goomba XI changes. Defaults: settings/default/map.lua.
-----------------------------------

xi = xi or {}
xi.settings = xi.settings or {}

xi.settings.map =
{
    -- The website's Yells page reads /yell and /shout lines from audit_chat.
    -- Tells, party and linkshell chat stay private and are not recorded.
    AUDIT_CHAT  = true,
    AUDIT_YELL  = true,
    AUDIT_SHOUT = true,

    -- Player-to-player transfers, for GM investigations.
    AUDIT_PLAYER_TRADES = true,
    AUDIT_PLAYER_BAZAAR = true,
    AUDIT_PLAYER_DBOX   = true,
    AUDIT_PLAYER_VENDOR = true,

    -- Triple EXP from kills (also capacity points). Keep main.lua's EXP_RATE the same.
    EXP_RATE = 3.0,

    -- Double the chance a synthesis raises crafting skill: 60% -> 100% below skill 50,
    -- 25% -> 50% from 50 up (halved when the synth breaks, as normal).
    CRAFT_CHANCE_MULTIPLIER = 2.0,

    -- Faster combat and magic skill-ups (automaton skills too). The server adds this many
    -- times the normal gain on top of it, so 2 makes each skill-up about 3x as large
    -- (0.1 -> 0.3) and raises the most one skill-up can give from 0.5 to 0.9.
    -- Must be a whole number; 1 = retail.
    SKILLUP_AMOUNT_MULTIPLIER = 2,

    -- Fishing (LandSandBoat ships with it off). FISHING_SKILL_MULTIPLIER doubles the chance
    -- that a catch raises fishing skill (retail's 1.0 is very slow). Fish, items and bites
    -- are unchanged. FISHING_ENABLE = false turns fishing and its quests off again.
    FISHING_ENABLE           = true,
    FISHING_SKILL_MULTIPLIER = 2.0,
}
