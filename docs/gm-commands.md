# GM commands

Every in-game command on this server, read from `scripts/commands/` in the LandSandBoat build it runs. In game, commands start with `!` (for example `!pos`, `!additem`). Give yourself command access with `sudo goomba gm <account> 5` on the game server; the **Level** column is the minimum GM level a command needs.

207 commands.

| Command | Level | What it does |
| --- | --- | --- |
| `!addabytime` | 1 | Adds an amount of time to the given target. If no target then to the current player. |
| `!addallatma` | 1 | Adds all Atma Key Items to the given player. |
| `!addallattachments` | 1 | Unlocks all attachments |
| `!addallmaps` | 1 | Adds all maps to the given player. |
| `!addallmonstrosity` | 1 | Adds all species, instincts, and variants for monstrosity |
| `!addallmounts` | 1 | Adds all mount key items to player, granting access to their associated mounts |
| `!addallspells` | 1 | Adds all valid spells EXCEPT TRUSTS to the given target. If no target then to the current player. |
| `!addalltrusts` | 1 | Adds all trust spells to the given target. If no target then to the current player. |
| `!addallwarps` | 1 | Adds all Survival Guides and Home Points to GM if no target is specified. |
| `!addallweaponskills` | 1 | Adds all learned weaponskills to the given target. If no target then to the current player. |
| `!addcurrency <currency type> <amount> <target player>` | 1 | Adds the specified currency to the player |
| `!adddynatime` | 1 | Adds an amount of time to the given target. If no target then to the current player. |
| `!addeffect` | 1 | Adds the given effect to the given player. |
| `!addfish <fishId> <length> <weight>` | 3 | Adds a measured fish to the GMs inventory. |
| `!additem <itemId> <quantity> <aug1> <v1> <aug2> <v2> <aug3> <v3> <aug4> <v4> <trial>` | 1 | Adds an item to the GMs inventory. |
| `!addkeyitem <ID> <player>` | 1 | Adds a key item to the player. |
| `!addlights <light type> <amount> <target player>` | 1 | Adds the amount of specified light to the player |
| `!addmission <logID> <missionID> <player>` | 1 | Adds a mission to the GM or target players log. |
| `!addquest <logID> <questID> <player>` | 1 | Adds a quest to the given targets log. |
| `!addspell <spellID> <player>` | 1 | adds the ability to use a spell to the player |
| `!addtempitem` | 1 | Adds a temp item to the players inventory. |
| `!addtime` | 5 | Resets and then adds offset (in seconds) to earth clock. |
| `!addtitle` | 1 | Add and set player title. |
| `!addtreasure <itemId> <target player/party/alliance>` | 1 | Adds an item directly to the treasure pool. |
| `!addWeaponSkillPoints <slot> <points> (player)` | 1 | Adds weapon skill points to an equipped item. |
| `!afkcheck` | 1 | Sends a custom menu to the cursor target, |
| `!ah` | 1 | opens the Auction House menu anywhere in the world |
| `!animatenpc` | 1 | Changes the animation of the given npc. (For testing purposes.) |
| `!animatesubnpc` | 1 | Changes the animationSub of the given npc. (For testing purposes.) |
| `!animation` | 1 | Sets the players current animation. |
| `!besieged <subcommand> ...` | 1 | Drives Besieged by hand until the system runs itself. |
| `!breaklinkshell` | 4 | Breaks a linkshell and all pearls/sacks |
| `!bring <player>` | 1 | Brings the target to the player. |
| `!build` | 0 | Print the server's current build information |
| `!cansee <target>` | 1 | Can you see (via ximesh raycasting) your cursor target? |
| `!capallskills` | 1 | Caps all the players skills. |
| `!capskill` | 1 | Caps a specific skill. |
| `!changejob` | 1 | Changes the players current job. |
| `!changesjob` | 1 | Changes the players current subjob. |
| `!checkinstance` | 1 | Displays Progress and Stage inside instance |
| `!checkinteraction (handlerName)` | 5 | ----------------------------------- |
| `!checklocalvar <varName> { 'player'/'mob'/'npc' } { name/ID }` | 1 | checks player or npc local variable and returns result value. |
| `!checkmission <Log ID> <Player>` | 1 | Prints current MissionID for the given LogID and target Player to the in game chatlog |
| `!checkmissionstatus <Log ID> <Player>` | 1 | Prints current missionStatus for the given LogID and target Player to the in game chatlog |
| `!checkquest <logID> <questID> (player)` | 1 | Prints status of the quest to the in game chatlog |
| `!checkvar <varType> <varName>` | 1 | checks player or server variable and returns result value. |
| `!chocobo <color> <head> <tail> <feet>` | 1 | Register and use a chocobo with a specific look |
| `!cnation <target> <campaign allegiance>` | 1 | check or alter target characters campaign allegiance |
| `!completemission <logID> <missionID> <player>` | 1 | Completes the given mission for the target player, if that mission is currently active. |
| `!completequest <logID> <questID> <player>` | 1 | Completes the given quest for the GM or target player. |
| `!completerecord <recordID> <player>` | 1 | Completes the given quest for the GM or target player. |
| `!costume` | 1 | Sets the players current costume. |
| `!costume2` | 1 | Sets the players current costume2. |
| `!cp` | 1 | Adds the given amount cp to the player. |
| `!crash` | 5 | force the server process to crash |
| `!cs` | 1 | Starts the given event for the player. |
| `!cs2` | 1 | Starts the given event for the player. |
| `!delallinventory` | 1 | Deletes all items in a player's inventory, if they have any. |
| `!delallweaponskills` | 1 | Removes all learned weaponskills to the given target. If no target then to the current player. |
| `!delcontaineritems` | 1 | Deletes all items in a player's specified container, if they have any. |
| `!delcurrency <currency type> <amount> <target player>` | 1 | Removes the specified currency from the player |
| `!addeffect` | 1 | Removes the given effect from the given player. |
| `!delitem` | 1 | Deletes a single item held by a player, if they have it. |
| `!delkeyitem` | 1 | Deletes the given key item from the player. |
| `!delmission <logID> <missionID> <player>` | 1 | Deletes the given mission from the GM or target player. |
| `!delquest <logID> <questID> <player>` | 1 | Deletes the given quest from the GM or target player. |
| `!delspell <spellID> <player>` | 1 | Removes a spell from the players spell list. |
| `!despawnmob <mobid-optional>` | 1 | Despawns the given mob <t> or mobID) |
| `!down <optional number> <optional target>` | 1 | Alters vertical coordinate |
| `!entityVisual` | 1 | push entityVisual packet to player |
| `!exec` | 4 | Allows you to execute a Lua string directly from chat. |
| `!fafnir` | 5 | Summon a fightable Fafnir (no loot) |
| `!garrison <command> (player)` | 1 |  |
| `!gc_full` | 5 | Tell Lua to run a full garbage collection |
| `!gc_step` | 5 | Tell Lua to run a garbage collection step |
| `!getcraftRank <craft skill or ID> (player)` | 1 | returns target's RANK of specified craft skill |
| `!geteffects [target]` | 1 | Lists all active status effects on the specified target (or self if no target specified) |
| `!getenmity` | 2 | prints the target mob's current CE and VE towards you |
| `!getfame` | 3 | Gets fame level of a target player |
| `!getfamily <optional MobID>` | 1 | Prints the mob's family ID. |
| `!getfishers <MinutesToLookback>` | 1 | Returns a list of all players who have recently fished. |
| `!getid` | 1 | Prints the ID of the currently selected target under the cursor |
| `!getlocalvars` | 1 |  |
| `!getmobaction` | 1 | Prints mob's current action to the command user. |
| `!getmobflags <optional MobID>` | 1 | Used to get a mob's entity flags for testing. |
| `!getmobmod <modID>` | 1 | gets a mod by ID on the player or cursor target |
| `!getmod <modID>` | 3 | gets a mod by ID on the player or cursor target |
| `!getpool` | 3 | prints the treasure pool of the current target. |
| `!getprevzoneline` | 1 | gets the ID of the players last zoneline or cursor target. |
| `!getquestvar` | 1 |  |
| `!getskill <skill name or ID> <target>` | 1 | returns target's level of specified skill |
| `!getspecies <optional MobID>` | 1 | Prints the mob's species ID. |
| `!getstats` | 1 | prints stats of cursor target into chatlog, for debugging. |
| `!getta` | 1 | returns the name of the entity that would be chosen for trick attack given the current (mob) target |
| `!gettp` | 1 | prints tp of the player and the target(if applicable), for debugging. |
| `!getwspoints` | 1 | prints current ws points, optionaly specifying the weapon slot to check (default main) |
| `!givebonanzapearl <player> <number> <eventnum>` | 5 | Gives a bonanza pearl with <number> for <eventnum> |
| `!givegil <amount> <player>` | 1 | Gives the specified amount of gil to GM or target player. |
| `!giveitem <player> <itemId> <amount> <aug1> <v1> <aug2> <v2> <aug3> <v3> <aug4> <v4>` | 1 | Gives an item to the target player. |
| `!givels` | 1 | Makes a linkpearl for the given linkshell (pearlsack for gm) |
| `!givemagianitem <player> <trialId> (RewardItem = False)` | 1 | Gives the Magian Item associated with the given Trial ID |
| `!givexp <amount> <player>` | 1 | Gives the GM or target player experience points. |
| `!gmhome` | 1 | Sends you to zone 210 (GM_HOME), if you are a GM |
| `!godmode` | 1 | Toggles god mode on the player, granting them several special abilities. |
| `!goto` | 1 | Goes to the target player. |
| `!gotoid` | 1 | Go to given mob or npc ID |
| `!gotoname` | 1 | Go to given mob or npc by name |
| `!hasitem` | 1 | Checks if a player has a specific item |
| `!haskeyitem <ID> <player>` | 1 | Checks if player has specified KeyItem. |
| `!hastitle` | 1 | Check if player already has a title. |
| `!hide` | 1 | Hides the GM from other players. |
| `!homepoint` | 1 | Sends the target to their homepoint. |
| `!hp <amount> <player>` | 1 | Sets the GM or target players health. |
| `!immortal <player>` | 1 | Sets a target to be unkillable |
| `!inject` | 1 | Injects the given packet data. |
| `!injectaction` | 1 | Injects an action packet with the specified action and animation id. |
| `!instance <instance_id>` | 1 | Load an instance and take you there |
| `!inwater <target>` | 1 | Are you in water? |
| `!jail` | 1 | Sends the target player to jail. (Mordion Gaol) |
| `!logoff` | 1 | Logs the target player off by force. |
| `!masterjob` | 1 | Masters the player's current job |
| `!menu` | 1 | Shows a basic test menu with three options |
| `!menu_paginated` | 1 | Shows a paginated test menu with two pages, an option per page. |
| `!messagebasic` | 1 | Injects a message basic packet. |
| `!messagespecial` | 1 | Injects a message special packet. |
| `!messagestandard` | 1 | Injects a standard message packet. |
| `!minigame` | 1 | Opens a menu to allow you to quickly test minigames. |
| `!mission <logid> <missionid> optional <player-name>, logid and mission ids work by numbers or string.format` | 1 | mission command built with menu control, can add/delete/complete missions, see status, |
| `!mobhere <mobId>` | 1 | Spawns a MOB and then moves it to the current position, if in same zone. |
| `!mobskill` | 1 | Forces an entity to do a skill |
| `!mobsub` | 1 | Changes the sub-animation of the given mob. (For testing purposes.) |
| `!monstrosity` | 1 | Toggles MON, keeping the current position. Leaving restores the jobs held on entry. |
| `!monunlock <species or variant> (player)` | 1 | Unlocks one Monstrosity family or variant by its enum name, such as TIGER or FLOWERING_TREANT. |
| `!mount` | 1 |  |
| `!mp <amount> <player>` | 1 | Sets the GM or target players mana. |
| `!naga` | 5 | POC for Domain Invasion and fenced content in general. |
| `!npchere <npcId>` | 1 | Spawns an NPC and then moves it to the current position, if in same zone. |
| `!pardon` | 1 | Pardons a player from jail. (Mordion Gaol) |
| `!petgodmode` | 1 | Toggles god mode on the player's pet, granting them several special abilities. |
| `!pettp` | 1 | Sets the players pet tp. |
| `!pos <x> <y> <z> <optional zone> <optional target>` | 1 | Sets the players position. If none is given, prints out the position instead. |
| `!posemannequin` | 1 | changes the pose of a mannequin |
| `!posfix` | 1 | Resets a targets account session and warps them to Jeuno. |
| `!promote` | 1 | Promotes the player to a new GM level. |
| `!provokeall` | 1 | Makes all enemies in the current zone target you and sets their TP to 3000. |
| `!quest <logid> <questid> optional <player-name>, logid and quest ids work by numbers or string.format` | 1 | quest command built with menu control, can add/delete/complete quests, see status, |
| `!racechange <player>` | 3 | Make player eligible for Ancestry Moogle Race Change service. |
| `!raise <power> <player>` | 1 | Sends raise menu to GM or target player. |
| `!rebuildnavmesh` | 5 | Rebuild the navmesh for the current zone with configurable parameters |
| `!release` | 1 | Releases the player from current events. |
| `!reloadbattlefield` | 5 | Attempt to reload specified battlefield lua without a restart. |
| `!reloaddefaultactions` | 5 | Reloads default actions for current zone or all |
| `!reloadglobal` | 4 | Attempt to reload specified global lua without a restart. |
| `!reloadinteractions` | 5 | Reloads the interaction framework |
| `!reloadmagians` | 5 | Reloads the magian listeners |
| `!reloadnavmesh` | 5 | Reload the navmesh for the current zone |
| `!reloadquest` | 5 | Attempt to reload specified quest lua without a restart. |
| `!reloadrecipes` | 5 | Reloads crafting recipes from the DB |
| `!rename` | 1 | Renames target NPC or MOB. Limited to 16 character spaces. |
| `!reset <player>` | 1 | If no name is specified, resets your own JA timers. |
| `!resetlights` | 1 | resets all lights to 0 |
| `!return <player>` | 1 | Warps GM or target player to their previous zone |
| `!send <player1> (<player2) or zone)` | 1 | Teleport a player to: |
| `!setallegiance` | 1 | Sets the players allegiance. |
| `!setbag` | 1 | Sets the players bag size |
| `!setbattlefieldtime` | 4 | Set time limit for an active battlefield |
| `!setcapacitypoints <amount> <player>` | 1 | Sets the target players job points count. |
| `!setcraftRank <craft skill or ID> <craft rank> <target>` | 1 | sets target's RANK of specified craft skill |
| `!setfamelevel` | 3 | Sets fame level on a target player |
| `!setgil` | 1 | Sets the players gil. |
| `!setjobpoints <amount> <player>` | 1 | Sets the target players job points count. |
| `!setlocalvar <varName> <player/mob/npc> <ID>` | 3 | set player npc or mob local variable and value. |
| `!setmentor <MentorMode> <target>` | 1 | 0 = Not a mentor, 1 = Unlocked but inactive, 2 = Unlocked & flag on. |
| `!setmerits <amount> <player>` | 1 | Sets the target players merit count. |
| `!setmissionstatus (player) (value) (log ID) (index)` | 1 | Sets missionStatus for the given LogID and target Player |
| `!setmobflags <flags> <optional MobID>` | 1 | Used to manipulate a mob's nameflags for testing. |
| `!setmoblevel` | 1 | Sets the target monsters level. |
| `!setmobmod` | 3 | Sets the specified mob modifier to the specified value on the cursor target mob |
| `!setmod` | 1 | Sets the specified modifier to the specified value on the cursor target or player |
| `!setmusic <typeID> <songID>` | 1 | Temporarily changes music played by users client |
| `!setplayerlevel` | 1 | Sets the target players level. |
| `!setplayermodel <modelid> <slot> <player>` | 1 | Sets the look of the user or target player based on model id offset and slot (for testing). |
| `!setplayernation` | 1 | Sets the target players nation. |
| `!setplayervar` | 1 | Sets a variable on the target player. |
| `!setProgress` | 1 | changes progress inside an instance |
| `!setquestvar` | 1 |  |
| `!setrank` | 1 | Sets the players rank. |
| `!setskill <skill name or ID> <skill level> <target>` | 1 | sets target's level of specified skill |
| `!setStage` | 1 | changes stage inside an instance |
| `!setweather` | 1 | Sets the current weather for the current zone. |
| `!sleep` | 5 | inject an artificial delay of 1 second (FOR LOCAL PERFORMANCE TESTING ONLY) |
| `!spawnmob` | 1 | Spawns a mob. |
| `!speed` | 1 | Sets the players movement speed. |
| `!stun` | 3 | stuns a non-NPC target for an hour. good for testing damage/mechanics on a punching bag. |
| `!takegil <amount> <player>` | 1 | Removes the amount of gil from the given player. |
| `!takexp <amount> <player>` | 1 | Removes experience points from the target player. |
| `!time` | 1 | Prints time info. |
| `!togglegm` | 1 | Toggles a GMs nameflags/icon. |
| `!tp <amount> <player>` | 1 | Sets a players tp. If they have a pet, also sets pet tp. |
| `!trustengage` | 0 | Sets the engagement type of a players trusts |
| `!up <optional number> <optional target>` | 1 | Alters vertical coordinate |
| `!updateconquest` | 1 | Updates all conquest guard. (Need modify in db first.) |
| `!uptime` | 1 | prints zone uptime |
| `!wallhack <optional target>` | 1 | Allows the player to walk through walls. |
| `!where` | 1 | Tells the player about their current position. |
| `!yell` | 1 | Bans a specified player from using /yell. |
| `!zone` | 1 | Teleports a player to the given zone. |
