-----------------------------------
-- Goomba XI: welcome message
-----------------------------------
-- A small example module: greets players when they log in (not when they zone).
-- Copy this file as a starting point for your own changes. Every module overrides a
-- function from scripts/ with m:addOverride('<function name>', ...) and calls super(...)
-- to keep the original behaviour.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('goomba_welcome')

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if not zoning then
        -- Wait a moment so the message isn't lost in the login messages.
        player:timer(3000, function(p)
            p:printToPlayer('Welcome to Goomba XI!', xi.msg.channel.SYSTEM_3, '')
        end)
    end
end)
