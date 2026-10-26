-----------------------------------
-- Goomba XI: solo-friendly trusts
-----------------------------------
-- Goomba XI is a preservation server meant to be playable solo or in a small group, with
-- trusts standing in for other players. Retail ties the 4th and 5th trust, and trusts in
-- Limit Break 5 fights, to Rhapsodies of Vana'diel key items this 75-era server can't give,
-- and bars trusts from many zones and battlefields. This module lifts those limits and
-- gives every character a starter party. Trust quests and ciphers still work as on retail.
--
-- Needs ENABLE_TRUST_CASTING = 1 in settings/main.lua. Change the options below, then:
--   sudo goomba apply && sudo goomba restart game
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('goomba_solo_trusts')

local settings =
{
    -- Trusts one player may call at once (retail: 3, or 5 with RoV key items). 1-5.
    maxTrusts = 5,

    -- Allow trusts in every zone and every battlefield, including Limit Break 5 fights
    -- and battles marked "no trusts". false = retail zone and battlefield rules.
    everywhere = true,

    -- Trusts every character knows. Taught on login, so existing characters get them too.
    -- Their trust quests can still be done; learning a known trust again does nothing.
    -- Names as in xi.magic.spell (scripts/enum/magic.lua).
    starterTrusts =
    {
        'EXCENMILLE', -- Paladin: tank
        'KUPIPI',     -- White Mage: healer
        'NAJI',       -- Warrior: melee damage
        'AYAME',      -- Samurai: melee damage
        'SHANTOTTO',  -- Black Mage: magic damage
    },

    -- Trusts nobody may call: their jobs (Geomancer, Rune Fencer, Dancer, Scholar) arrived after
    -- the 75 era and bring spells and abilities the 2007 client doesn't know. Applies however the
    -- trust was learned (quest, GM command). Remove a line to allow that trust again.
    blockedTrusts =
    {
        'SAKURA',                -- Sakura (GEO)
        'MOOGLE',                -- Moogle (GEO)
        'STAR_SIBYL',            -- Star Sibyl (GEO)
        'LILISETTE',             -- Lilisette (DNC)
        'MUMOR',                 -- Mumor (DNC)
        'UKA_TOTLIHN',           -- Uka Totlihn (DNC)
        'KUYIN_HATHDENNA',       -- Kuyin Hathdenna (GEO)
        'MAYAKOV',               -- Mayakov (DNC)
        'ADELHEID',              -- Adelheid (SCH)
        'AMCHUCHU',              -- Amchuchu (RUN)
        'BRYGID',                -- Brygid (GEO)
        'KUPOFRIED',             -- Kupofried (GEO)
        'SYLVIE_UC',             -- Sylvie (UC) (GEO)
        'LILISETTE_II',          -- Lilisette II (DNC)
    },
}

local maxPartySize = 6

-- In a battlefield, trusts may fill the party up to six even where the battlefield allows
-- fewer people (a solo Limit Break fight allows one), so a solo player can bring a party.
m:addOverride('xi.trust.checkBattlefieldTrustCount', function(caster)
    if not settings.everywhere then
        return super(caster)
    end

    local battlefield = caster:getBattlefield()
    if not battlefield then
        return true
    end

    local numTrusts = 0
    for _, entity in ipairs(battlefield:getPlayersAndTrusts()) do
        if entity:getObjType() == xi.objType.TRUST then
            numTrusts = numTrusts + 1
        end
    end

    local limit = math.max(battlefield:getMaxParticipants(), maxPartySize)
    return battlefield:getPlayerCount() + numTrusts < limit
end)

-- The same checks as retail's xi.trust.canCast, minus the Rhapsody key item limits and,
-- with `everywhere`, the zone and battlefield bans. The rest stays: party leader or solo
-- only, no enmity, no alliance (trusts only join a party), one of each trust.
local blocked = nil -- spell id -> true, built on first use (xi.magic.spell is loaded by then)

local function isBlocked(spellId)
    if not blocked then
        blocked = {}
        for _, name in ipairs(settings.blockedTrusts) do
            local id = xi.magic.spell[name]
            if id then
                blocked[id] = true
            end
        end
    end

    return blocked[spellId] == true
end

m:addOverride('xi.trust.canCast', function(caster, spell, notAllowedTrustIds)
    if xi.settings.main.ENABLE_TRUST_CASTING == 0 then
        return xi.msg.basic.TRUST_NO_CAST_TRUST
    end

    if isBlocked(spell:getID()) then
        return xi.msg.basic.TRUST_NO_CAST_TRUST
    end

    if caster:getGMLevel() > 0 and caster:getVisibleGMLevel() >= 3 then
        return 0
    end

    if
        caster:checkSoloPartyAlliance() == 2 or
        caster:hasKeyItem(xi.keyItem.GLADIATORIAL_WRIT_OF_SUMMONS)
    then
        return xi.msg.basic.TRUST_NO_CAST_TRUST
    end

    if not settings.everywhere and not caster:canUseMisc(xi.zoneMisc.TRUST) then
        return xi.msg.basic.TRUST_NO_CALL_AE
    end

    local leader = caster:getPartyLeader()
    if leader and caster:getID() ~= leader:getID() then
        caster:messageSystem(xi.msg.system.TRUST_SOLO_OR_LEADER)
        return -1
    end

    if caster:isSeekingParty() then
        caster:messageSystem(xi.msg.system.TRUST_NO_SEEKING_PARTY)
        return -1
    end

    if GetSystemTime() - caster:getPartyLastMemberJoinedTime() < 120 then
        caster:messageSystem(xi.msg.system.TRUST_DELAY_NEW_PARTY_MEMBER)
        return -1
    end

    if caster:hasEnmity() then
        caster:messageSystem(xi.msg.system.TRUST_NO_ENMITY)
        return -1
    end

    local blocked = {}
    if type(notAllowedTrustIds) == 'number' then
        blocked[notAllowedTrustIds] = true
    elseif type(notAllowedTrustIds) == 'table' then
        for _, id in pairs(notAllowedTrustIds) do
            blocked[id] = true
        end
    end

    local numPt     = 0
    local numTrusts = 0
    for _, member in pairs(caster:getPartyWithTrusts()) do
        if member:getObjType() == xi.objType.TRUST then
            local id = member:getTrustID()
            if id == spell:getID() or blocked[id] then
                caster:messageSystem(xi.msg.system.TRUST_ALREADY_CALLED)
                return -1
            end

            numTrusts = numTrusts + 1
        end

        numPt = numPt + 1
    end

    if numPt >= maxPartySize or numTrusts >= settings.maxTrusts then
        caster:messageSystem(xi.msg.system.TRUST_MAXIMUM_NUMBER)
        return -1
    end

    if not settings.everywhere then
        local battlefieldId = caster:getBattlefieldID()
        local content       = xi.battlefield.contents[battlefieldId]
        if content and not content.allowTrusts then
            return xi.msg.basic.TRUST_NO_CAST_TRUST
        end
    end

    if not xi.trust.checkBattlefieldTrustCount(caster) then
        return xi.msg.basic.TRUST_NO_CAST_TRUST
    end

    return 0
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if zoning then
        return
    end

    for _, name in ipairs(settings.starterTrusts) do
        local spellId = xi.magic.spell[name]
        if spellId and not player:hasSpell(spellId) then
            player:addSpell(spellId, { silentLog = true })
        end
    end
end)
