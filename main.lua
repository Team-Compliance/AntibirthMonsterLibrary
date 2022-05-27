AntiMonsterLib = RegisterMod("Antibirth Monster Library", 1)
local mod = AntiMonsterLib
local game = Game()



--[[/////////////////////////////////////////--
	HOW TO USE BLACKLIST FUNCTIONS:

Adding / Removing entry:
AMLblacklistEntry(blacklist, Type, Variant, SubType, operation)
	there are 3 possible blacklists: "Coil", "Necromancer" and "Corpse Eater"
	the possible operations are "add" and "remove"
	if the function fails (eg. if you're trying to remove an entry that doesn't exist), it will give an error in the console and return false, otherwise it will return true
	setting the Type or Variant to -1 will include all variants or subtypes

Checking for blacklist entries:
inAMLblacklist(blacklist, checkType, checkVariant, checkSubType)
	there are 3 possible blacklists: "Coil", "Necromancer" and "Corpse Eater"
	returns true if the specified entity is in the blacklist, returns false otherwise
	setting the Type or Variant to -1 will include all variants or subtypes



	HOW TO USE CORPSE EATER EFFECT FUNCTIONS:
	
Adding / Removing entry:
EatenEffectEntry(Type, Variant, SubType, operation, effect)
	there are 5 possible effects: "small" (reduced effects, no projectiles), "bone", "poop", "stone", "dank" (unique projectiles)
	if an entity doesn't have an effect entry it will default to regular blood projectiles with occasional bone ones
	the possible operations are "add" and "remove"
	if the function fails (eg. if you're trying to remove an entry that doesn't exist), it will give an error in the console and return false, otherwise it will return true
	setting the Type or Variant to -1 will include all variants or subtypes
	
Checking for effect entries:
GetEatenEffect(checkType, checkVariant, checkSubType)
	returns the entities effect group as a string if it has an entry, returns false otherwise
	setting the Type or Variant to -1 will include all variants or subtypes
--/////////////////////////////////////////]]--



--[[--------------------------------------------------------
    Enums
--]]--------------------------------------------------------

-- Monsters
EntityType.ENTITY_AML = 200
EntityType.ENTITY_DUMPLING = 800
EntityType.ENTITY_BLIND_BAT = 803
EntityType.ENTITY_STRIFER = 839
EntityType.ENTITY_NIGHTWATCH = 842
EntityType.ENTITY_VESSEL = 858


-- Variants of the AML entity
AMLVariants = {
	DUMPLING = 2401, -- for backwards compatibility
	SKINLING = 2402, -- for backwards compatibility
	SCAB = 2403, -- for backwards compatibility
	COIL = 2406,
	ECHO_BAT = 2407,
	SCREAMER = 2408,
	STILLBORN = 2409,
	NECROMANCER = 2410,
	RED_TNT = 3400
}


-- Variants of already existing entities
EntityVariant = {
	FRACTURE = 801, -- for EntityType.ENTITY_HOPPER
	SWAPPER = 835, -- for EntityType.ENTITY_BABY
	BARFY = 850, -- for EntityType.ENTITY_FATTY
	CORPSE_EATER = 100, -- for EntityType.ENTITY_GRUB
	CARRION_RIDER = 101 -- for EntityType.ENTITY_GRUB
}


-- Projectile variants
ProjectileVariant.PROJECTILE_ECHO = 104
ProjectileVariant.PROJECTILE_LANTERN = 106

-- Effect variants
EffectVariant.NIGHTWATCH_SPOTLIGHT = 842
EffectVariant.SCREAMER_AURA = 867



--[[--------------------------------------------------------
    Blacklists
--]]--------------------------------------------------------

coil_blacklist = {
	{EntityType.ENTITY_LUMP, -1, -1},
	{EntityType.ENTITY_AML, AMLVariants.COIL, -1},
	{EntityType.ENTITY_AML, AMLVariants.RED_TNT, -1},
	{EntityType.ENTITY_GRUB, 100, 1}, -- Corpse eater body
	{EntityType.ENTITY_EVIS, 10, -1}, -- Evis cord
	{EntityType.ENTITY_NEEDLE, -1, -1},
}

necromancer_blacklist = {
	{EntityType.ENTITY_BONY, -1, AMLVariants.NECROMANCER}, -- Bonys spawned by Necromancers
	{EntityType.ENTITY_GRUB, 0, -1},
	{EntityType.ENTITY_GRUB, 100, 1}, -- Corpse eater body
	{EntityType.ENTITY_LITTLE_HORN, 1, -1}, -- Dark ball
	{EntityType.ENTITY_RAG_MEGA, 1, -1}, -- Purple ball
	{EntityType.ENTITY_BIG_BONY, 10, -1}, -- Bouncing bone
}

corpse_eater_blacklist = {
	{EntityType.ENTITY_FLY, -1, -1},
	{EntityType.ENTITY_ATTACKFLY, -1, -1},
	{EntityType.ENTITY_VIS, 22, -1}, -- Chubber projectile
	{EntityType.ENTITY_SUCKER, 4, -1}, -- Bulb
	{EntityType.ENTITY_SUCKER, 5, -1}, -- Bloodfly
	{EntityType.ENTITY_SPIDER, -1, -1},
	{EntityType.ENTITY_AML, AMLVariants.NECROMANCER, -1},
	{EntityType.ENTITY_DIP, -1, -1},
	{EntityType.ENTITY_RING_OF_FLIES, -1, -1},
	{EntityType.ENTITY_BONY, -1, -1},
	{EntityType.ENTITY_GRUB, 100, -1},
	{EntityType.ENTITY_GRUB, 101, -1},
	{EntityType.ENTITY_DART_FLY, -1, -1},
	{EntityType.ENTITY_BLACK_BONY, -1, -1},
	{EntityType.ENTITY_SWARM, -1, -1},
	{EntityType.ENTITY_CORN_MINE, -1, -1},
	{EntityType.ENTITY_HUSH_FLY, -1, -1},
	{EntityType.ENTITY_LITTLE_HORN, 1, -1}, -- Dark ball
	{EntityType.ENTITY_PORTAL, -1, -1},
	{EntityType.ENTITY_WILLO, -1, -1},
	{EntityType.ENTITY_BIG_BONY, -1, -1},
	{EntityType.ENTITY_WILLO_L2, -1, -1},
	{EntityType.ENTITY_REVENANT, -1, -1},
	{EntityType.ENTITY_ARMYFLY, -1, -1},
	{EntityType.ENTITY_SWARM_SPIDER, -1, -1},
	{EntityType.ENTITY_CULTIST, -1, -1},
}

-- Add / remove blacklist entry
function AMLblacklistEntry(blacklist, Type, Variant, SubType, operation)
	-- Error checking
	if blacklist ~= "Coil" and blacklist ~= "Necromancer" and blacklist ~= "Corpse Eater" then
		print("[AML] Error adding / removing blacklist entry:\n   Incorrect blacklist: " .. blacklist)
	end
	if operation ~= "add" and operation ~= "remove" then
		print("[AML] Error adding / removing blacklist entry:\n   Unknown operation: " .. operation)
		return false
	end

	-- Get blacklist
	local checkList = ""
	if blacklist == "Coil" then
		checkList = coil_blacklist
	elseif blacklist == "Necromancer" then
		checkList = necromancer_blacklist
	elseif blacklist == "Corpse Eater" then
		checkList = corpse_eater_blacklist
	end
	
	-- Add / remove
	for i,entry in pairs(checkList) do
		if operation == "add" then
			if entry[1] == Type and entry[2] == Variant and entry[3] == SubType then
				print("[AML] Error adding blacklist entry:\n   Entry already exists")
				return false
			end
		
		elseif operation == "remove" then
			if entry[1] == Type and entry[2] == Variant and entry[3] == SubType then
				table.remove(checkList, i)
				return true
			end
		end
	end
	
	if operation == "add" then
		table.insert(checkList, {Type, Variant, SubType})
		return true
		
	elseif operation == "remove" then
		print("[AML] Error removing blacklist entry:\n   Entry doesn't exist")
		return false
	end
end

-- Check if the entity is in the blacklist or not
function inAMLblacklist(blacklist, checkType, checkVariant, checkSubType)
	if blacklist ~= "Coil" and blacklist ~= "Necromancer" and blacklist ~= "Corpse Eater" then
		print("[AML] Error checking blacklist:\n   Incorrect blacklist: " .. blacklist)
		return
	end
	
	local checkList = ""
	if blacklist == "Coil" then
		checkList = coil_blacklist
	elseif blacklist == "Necromancer" then
		checkList = necromancer_blacklist
	elseif blacklist == "Corpse Eater" then
		checkList = corpse_eater_blacklist
	end
	
	for i,entry in pairs(checkList) do
		if checkType == entry[1] and (entry[2] == -1 or checkVariant == entry[2]) and (entry[3] == -1 or checkSubType == entry[3]) then
			return true
		end
	end
	return false
end



--[[--------------------------------------------------------
    Corpse eater death effects for enemies
--]]--------------------------------------------------------

corpse_eater_effects = {
	small = {
	{EntityType.ENTITY_FLY, -1, -1},
	{EntityType.ENTITY_POOTER, -1, -1},
	{EntityType.ENTITY_ATTACKFLY, -1, -1},
	{EntityType.ENTITY_MOTER, -1, -1},
	{EntityType.ENTITY_SPIDER, -1, -1},
	{EntityType.ENTITY_BIGSPIDER, -1, -1},
	{EntityType.ENTITY_RING_OF_FLIES, -1, -1},
	{EntityType.ENTITY_DART_FLY, -1, -1},
	{EntityType.ENTITY_SWARM, -1, -1},
	{EntityType.ENTITY_HUSH_FLY, -1, -1},
	{EntityType.ENTITY_SMALL_LEECH, -1, -1},
	{EntityType.ENTITY_STRIDER, -1, -1},
	{EntityType.ENTITY_FLY_BOMB, -1, -1},
	{EntityType.ENTITY_SMALL_MAGGOT, -1, -1},
	{EntityType.ENTITY_ARMYFLY, -1, -1},
	{EntityType.ENTITY_SWARM_SPIDER, -1, -1},
	{EntityType.ENTITY_POOFER, -1, -1},
	},

	bone = {
	{EntityType.ENTITY_BOOMFLY, 4, -1}, -- Bone fly
	{EntityType.ENTITY_DEATHS_HEAD, 4, -1}, -- Red skull
	{EntityType.ENTITY_BONY, -1, -1},
	{EntityType.ENTITY_POLYCEPHALUS, 1, -1}, -- The Pile
	{EntityType.ENTITY_BLACK_BONY, -1, -1},
	{EntityType.ENTITY_MOMS_DEAD_HAND, -1, -1},
	{EntityType.ENTITY_FORSAKEN, -1, -1},
	{EntityType.ENTITY_BIG_BONY, -1, -1},
	{EntityType.ENTITY_REVENANT, -1, -1},
	{EntityType.ENTITY_NEEDLE, 1, -1}, -- Pasty
	{EntityType.ENTITY_CLICKETY_CLACK, -1, -1},
	{EntityType.ENTITY_MAZE_ROAMER, -1, -1},
	},
	
	stone = {
	{EntityType.ENTITY_HOST, 3, -1}, -- Hard host
	{EntityType.ENTITY_ULTRA_GREED, 1, -1}, -- Ultra Greedier
	{EntityType.ENTITY_BISHOP, -1, -1},
	{EntityType.ENTITY_ROCK_SPIDER, -1, -1},
	{EntityType.ENTITY_DANNY, 1, -1}, -- Coal boy
	{EntityType.ENTITY_BLASTER, -1, -1},
	{EntityType.ENTITY_QUAKEY, -1, -1},
	{EntityType.ENTITY_HARDY, -1, -1},
	{EntityType.ENTITY_VISAGE, -1, -1},
	},
	
	poop = {
	{EntityType.ENTITY_DIP, -1, -1},
	{EntityType.ENTITY_SQUIRT, 0, -1},
	{EntityType.ENTITY_DINGA, -1, -1},
	{EntityType.ENTITY_GURGLING, 2, -1}, -- Turdling
	{EntityType.ENTITY_DINGLE, -1, -1},
	{EntityType.ENTITY_CORN_MINE, -1, -1},
	{EntityType.ENTITY_BROWNIE, -1, -1},
	{EntityType.ENTITY_HENRY, -1, -1},
	{EntityType.ENTITY_DRIP, -1, -1},
	{EntityType.ENTITY_SPLURT, -1, -1},
	{EntityType.ENTITY_CLOGGY, -1, -1},
	{EntityType.ENTITY_DUMP, -1, -1},
	{EntityType.ENTITY_CLOG, -1, -1},
	{EntityType.ENTITY_COLOSTOMIA, -1, -1},
	{EntityType.ENTITY_TURDLET, -1, -1},
	},
	
	dank = {
	{EntityType.ENTITY_CLOTTY, 1, -1}, -- Clot
	{EntityType.ENTITY_CHARGER, 2, -1},
	{EntityType.ENTITY_GLOBIN, 2, -1},
	{EntityType.ENTITY_LEAPER, 1, -1},
	{EntityType.ENTITY_GUTS, 2, -1}, -- Slog
	{EntityType.ENTITY_MONSTRO2, 1, -1}, -- Gish
	{EntityType.ENTITY_SUCKER, 2, -1}, -- Ink
	{EntityType.ENTITY_DEATHS_HEAD, 1, -1},
	{EntityType.ENTITY_SQUIRT, 1, -1},
	{EntityType.ENTITY_TARBOY, -1, -1},
	{EntityType.ENTITY_GUSH, -1, -1},
	{EntityType.ENTITY_BUTT_SLICKER, -1, -1},
	},
}

-- Add / remove Corpse Eater effects
function EatenEffectEntry(Type, Variant, SubType, operation, effect)
	-- Error checking
	if effect ~= "small" and effect ~= "bone" and effect ~= "stone" and effect ~= "poop" and effect ~= "dank" then
		print("[AML] Error adding / removing Corpse eater effect entry:\n   Unknown effect: " .. effect)
	end
	if operation ~= "add" and operation ~= "remove" then
		print("[AML] Error adding / removing Corpse eater effect entry:\n   Unknown operation: " .. operation)
		return false
	end

	-- Get list
	local checkList = ""
	if effect == "small" then
		checkList = corpse_eater_effects.small
	elseif effect == "bone" then
		checkList = corpse_eater_effects.bone
	elseif effect == "stone" then
		checkList = corpse_eater_effects.stone
	elseif effect == "poop" then
		checkList = corpse_eater_effects.poop
	elseif effect == "dank" then
		checkList = corpse_eater_effects.dank
	end
	
	-- Add / remove
	for i,entry in pairs(checkList) do
		if operation == "add" then
			if entry[1] == Type and entry[2] == Variant and entry[3] == SubType then
				print("[AML] Error adding effect entry:\n   Entry already exists")
				return false
			end
		
		elseif operation == "remove" then
			if entry[1] == Type and entry[2] == Variant and entry[3] == SubType then
				table.remove(checkList, i)
				return true
			end
		end
	end
	
	if operation == "add" then
		table.insert(checkList, {Type, Variant, SubType})
		return true
		
	elseif operation == "remove" then
		print("[AML] Error removing effect entry:\n   Entry doesn't exist")
		return false
	end
end

-- Get Corpse eater effect
function GetEatenEffect(checkType, checkVariant, checkSubType)
	for effect,effectlist in pairs(corpse_eater_effects) do
		for i,entry in pairs(effectlist) do
			if checkType == entry[1] and (entry[2] == -1 or checkVariant == entry[2]) and (entry[3] == -1 or checkSubType == entry[3]) then
				return tostring(effect)
			end
		end
	end
	return false
end



--[[--------------------------------------------------------
    External monster files to require
--]]--------------------------------------------------------

local monsterScripts = {
	corpseEaters = include("scripts.corpseEaters"),
	dumplings = include("scripts.dumplings"),
	fracture = include("scripts.fracture"),
	stillborn = include("scripts.stillborn"),
	blindBats = include("scripts.blindBats"),
	echoBat = include("scripts.echoBat"),
	necromancer = include("scripts.necromancer"),
	swappers = include("scripts.swappers"),
	barfy = include("scripts.barfy"),
	strifers = include("scripts.strifers"),
	nightwatch = include("scripts.nightwatch"),
	vessel = include("scripts.vessel"),
	coils = include("scripts.coils"),
	screamer = include("scripts.screamer"),
	redTNT = include("scripts.redTNT")
}

--Load the external files.
for _, v in pairs(monsterScripts) do
    v.Init()
end



--[[--------------------------------------------------------
    Replace entities that use an old ID or a different one in Basement Renovator
--]]--------------------------------------------------------

function mod:replaceID(Type, Variant, SubType, GridIndex, Seed)
	--[[ DUMPLINGS ]]--
	if Type == 200 and (Variant == AMLVariants.DUMPLING or Variant == AMLVariants.SKINLING or Variant == AMLVariants.SCAB) then
		if not DumplingsMod then
			return {800, Variant - 2401, SubType}
		end

	--[[ FRACTURE ]]--
	elseif Type == 801 then
		return {29, 801, SubType}
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.replaceID)