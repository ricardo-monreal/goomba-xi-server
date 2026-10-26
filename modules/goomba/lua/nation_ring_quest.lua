-----------------------------------
-- Goomba XI: "A Small <Nation> Challenge" (nation ring quest)
-- e.g. "A Small Bastok Challenge"
-----------------------------------
-- On retail a new character only gets their nation's ring (San d'Orian, Bastokan or
-- Windurstian Ring) when their race is native to the nation they start in. This quest lets
-- any citizen earn it, whatever their race.
--
-- An envoy stands just inside the city gate, next to the gate guard, in Southern San d'Oria,
-- Bastok Markets and Windurst Woods. Talk to the envoy of your own nation, accept, then defeat
-- 10 monsters that give you experience points in each of the two areas outside your city:
--   San d'Oria: West Ronfaure and East Ronfaure
--   Bastok:     North Gustaberg and South Gustaberg
--   Windurst:   West Sarutabaruta and East Sarutabaruta
-- Monsters that check as "too weak" don't count; party members in the same area each get
-- credit. Return to the envoy for the ring. The ring is Rare, so a character who already has
-- it is told so; one who has lost it can do the quest again.
--
-- Progress is kept in character variables ([Goomba]Ring*). Edit the settings below, then:
-- sudo goomba apply && sudo goomba restart game
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('goomba_nation_ring_quest')

local killsPerArea = 10

-- Per nation: the ring, the two areas, and the envoy beside the city gate guard. To move an
-- envoy, stand where you want it in game and read the position with !pos.
local nations =
{
    [xi.nation.SANDORIA] =
    {
        nationName = "San d'Oria",
        cityName   = "Southern San d'Oria",
        ring       = xi.item.SAN_DORIAN_RING,
        ringName   = "San d'Orian Ring",
        areas      =
        {
            { zoneId = xi.zone.WEST_RONFAURE, name = 'West Ronfaure' },
            { zoneId = xi.zone.EAST_RONFAURE, name = 'East Ronfaure' },
        },
        envoy =
        {
            zone     = 'Southern_San_dOria',
            name     = 'Royal Envoy',
            look     = '0x010003041C101C201C301C401C50006000700000', -- Elvaan
            x        = 102.068, -- beside Arpevion, T.K., at the east gate
            y        = 0.000,
            z        = -51.688,
            rotation = 163,
        },
    },

    [xi.nation.BASTOK] =
    {
        nationName = 'Bastok',
        cityName   = 'Bastok Markets',
        ring       = xi.item.BASTOKAN_RING,
        ringName   = "Bastokan Ring",
        areas      =
        {
            { zoneId = xi.zone.NORTH_GUSTABERG, name = 'North Gustaberg' },
            { zoneId = xi.zone.SOUTH_GUSTABERG, name = 'South Gustaberg' },
        },
        envoy =
        {
            zone     = 'Bastok_Markets',
            name     = 'Republic Envoy',
            look     = '0x010002080E100720073007400E50006000700000', -- Galka
            x        = -346.016, -- beside Rabid Wolf, I.M., at the gate to South Gustaberg
            y        = -10.002,
            z        = -180.915,
            rotation = 215,
        },
    },

    [xi.nation.WINDURST] =
    {
        nationName = 'Windurst',
        cityName   = 'Windurst Woods',
        ring       = xi.item.WINDURSTIAN_RING,
        ringName   = "Windurstian Ring",
        areas      =
        {
            { zoneId = xi.zone.WEST_SARUTABARUTA, name = 'West Sarutabaruta' },
            { zoneId = xi.zone.EAST_SARUTABARUTA, name = 'East Sarutabaruta' },
        },
        envoy =
        {
            zone     = 'Windurst_Woods',
            name     = 'Federation Envoy',
            look     = '0x0100040717100520173017401750006000700000', -- Mithra
            x        = 103.813, -- beside Harara, W.W., at the gate to East Sarutabaruta
            y        = -5.000,
            z        = -50.242,
            rotation = 133,
        },
    },
}

-- Character variables
local varActive = '[Goomba]RingQuest'  -- nation + 1 while the quest is active, else 0
local varKills  = '[Goomba]RingKills'  -- suffixed with the area number: 1 or 2

local channel = xi.msg.channel.NS_SAY

local function say(player, npc, text)
    player:printToPlayer(text, channel, npc:getPacketName())
end

local function notify(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3, '')
end

local function kills(player, areaIndex)
    return player:getCharVar(varKills .. areaIndex)
end

local function clearQuest(player)
    player:setCharVar(varActive, 0)
    player:setCharVar(varKills .. 1, 0)
    player:setCharVar(varKills .. 2, 0)
end

local function questName(info)
    return string.format('A Small %s Challenge', info.nationName)
end

local function progressText(player, info)
    local parts = {}
    for i, area in ipairs(info.areas) do
        table.insert(parts, string.format('%s %d/%d', area.name, kills(player, i), killsPerArea))
    end

    return table.concat(parts, ', ')
end

local function isComplete(player, info)
    for i = 1, #info.areas do
        if kills(player, i) < killsPerArea then
            return false
        end
    end

    return true
end

-- New menus must wait a moment for the previous one to close.
local function showMenu(player, menu)
    player:timer(50, function(playerArg)
        playerArg:customMenu(menu)
    end)
end

local function offer(player, npc, nation, info)
    say(player, npc, string.format('Hello, adventurer! Are you up for a small %s challenge?', info.nationName))
    say(player, npc, string.format(
        'Defeat %d monsters in %s and %d in %s, ones that are a real test for you: anything too weak to teach you a thing won\'t count.',
        killsPerArea, info.areas[1].name, killsPerArea, info.areas[2].name))
    say(player, npc, string.format('Do that, and the %s is yours. Your party\'s victories count too, as long as you fight in the same area.', info.ringName))

    showMenu(player, {
        title   = 'Take the challenge?',
        options =
        {
            {
                'I\'m in!',
                function(playerArg)
                    clearQuest(playerArg)
                    playerArg:setCharVar(varActive, nation + 1)
                    say(playerArg, npc, string.format('Splendid! Off you go, and come back to me when you\'re done. (%s)', progressText(playerArg, info)))
                end,
            },
            {
                'Maybe later.',
                function(playerArg)
                    say(playerArg, npc, 'The offer stands. You know where to find me.')
                end,
            },
        },
    })
end

local function onTrigger(nation)
    local info = nations[nation]

    return function(player, npc)
        local playerNation = player:getNation()

        local home = nations[playerNation]
        if playerNation ~= nation and home then
            say(player, npc, string.format(
                'You serve %s, friend. My counterpart beside the gate guard in %s has a challenge for you.',
                home.nationName, home.cityName))
            return
        elseif playerNation ~= nation then
            return
        end

        if player:hasItem(info.ring) then
            clearQuest(player)
            say(player, npc, string.format('I see you already carry the %s. Wear it with pride!', info.ringName))
            return
        end

        local active = player:getCharVar(varActive)

        if active ~= nation + 1 then
            -- Not started, or started for another nation before changing allegiance.
            offer(player, npc, nation, info)
            return
        end

        if not isComplete(player, info) then
            say(player, npc, string.format('Keep at it, adventurer! So far: %s.', progressText(player, info)))
            return
        end

        if npcUtil.giveItem(player, info.ring) then
            clearQuest(player)
            say(player, npc, string.format('Well fought! %s is proud to call you one of its own.', info.nationName))
        end
    end
end

-- Count kills. The core calls this once for each party and alliance member in the zone.
m:addOverride('xi.mob.onMobDeathEx', function(mob, player, isKiller, isWeaponSkillKill)
    super(mob, player, isKiller, isWeaponSkillKill)

    if not player or player:getObjType() ~= xi.objType.PC then
        return
    end

    local active = player:getCharVar(varActive)
    if active == 0 then
        return
    end

    local info = nations[active - 1]
    if not info then
        return
    end

    local zoneId = mob:getZoneID()
    for i, area in ipairs(info.areas) do
        if area.zoneId == zoneId then
            local count = kills(player, i)
            if count < killsPerArea and player:checkKillCredit(mob) then
                count = count + 1
                player:setCharVar(varKills .. i, count)
                notify(player, string.format('%s: %s %d/%d.', questName(info), area.name, count, killsPerArea))

                if isComplete(player, info) then
                    notify(player, string.format('%s complete! Return to the %s in %s.', questName(info), info.envoy.name, info.cityName))
                end
            end

            return
        end
    end
end)

for nation, info in pairs(nations) do
    m:addOverride(string.format('xi.zones.%s.Zone.onInitialize', info.envoy.zone), function(zone)
        super(zone)

        zone:insertDynamicEntity({
            objtype   = xi.objType.NPC,
            name      = info.envoy.name,
            look      = info.envoy.look,
            x         = info.envoy.x,
            y         = info.envoy.y,
            z         = info.envoy.z,
            rotation  = info.envoy.rotation,
            widescan  = 1,
            onTrigger = onTrigger(nation),
        })
    end)
end

