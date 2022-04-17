AntiMonsterLib = RegisterMod("Antibirth Monster Library", 1)
local mod = AntiMonsterLib
local game = Game()


--[[--------------------------------------------------------

    External monster files to require

--]]--------------------------------------------------------

local monsters = {
	corpseEaters = include("scripts.corpseEaters"),
	dumplings = include("scripts.dumplings"),
	--fracture = include("scripts.fracture"),
	stillborn = include("scripts.stillborn"),
    blindBats = include("scripts.blindBats"),
	necromancer = include("scripts.necromancer"),
	swappers = include("scripts.swappers"),
	strifers = include("scripts.strifers"),
	--nightwatch = include("scripts.nightwatch"),
    vessel = include("scripts.vessel")
	--screamer = include("scripts.screamer")
}


--[[
    Enum for all monster variants
--]]
local MonsterVariants = {
    DUMPLING=2401, -- for backwards compatibility
    SKINLING=2402, -- for backwards compatibility
    SCAB=2403, -- for backwards compatibility
    COIL=2406,
    --FRACTURE=2407,
	--SCREAMER=2408,
	STILLBORN=2409,
	NECROMANCER=2410,
	REDTNT=3400
}


--[[
    Floor record of rooms containing coils, collects
    room ids and locations, resets on new stage.
--]]
local CoilRoomRecord = {}
local RedTNTRoomRecord = {}


--[[
    Blacklist of enemies coils should NOT link to
--]]
local coil_blacklist = {
    "865.10", -- Evis guts
    "200.2406", -- Coils themselves
	"200.3400", -- Red TNT
    "33.0", "33.1", "33.2", "33.3", "33.10", "33.12", "33.13" -- Fireplaces and moveable fires
    }


--[[--------------------------------------------------------

Functions below supplement the callback functions,
and should be docstring'd with what they're used for.

--]]--------------------------------------------------------


--[[
    Checks if variant matches a dumpling for backwards compatibility
--]]
local function isDumpling(variant)
    return variant == MonsterVariants.DUMPLING or variant == MonsterVariants.SKINLING or variant == MonsterVariants.SCAB
end


--[[
    Checks if a given npc is coil blacklisted
--]]
local function isBlacklisted(npc)
    for _,v in pairs(coil_blacklist) do
        if v == (npc.Type.."."..npc.Variant) or (npc:GetEntityFlags() & EntityFlag.FLAG_FRIENDLY == EntityFlag.FLAG_FRIENDLY) then
            npc:GetData()["CoilBlacklist"] = true
            return true
        end
    end
    return false
end


--[[
    Helper function to connect a coil and enemy pair with a laser
--]]
local function addLaser(npc_target, coil_source)
    if not isBlacklisted(npc_target) then  
        local laser_source_pos = Vector(coil_source.Position.X, coil_source.Position.Y-10)
        local laser_ent_pair = {laser=EntityLaser.ShootAngle(2, laser_source_pos, ((npc_target.Position - laser_source_pos):GetAngleDegrees()), 0, Vector(0, -30), coil_source), npc=npc_target}
        local _, endPos = Game():GetRoom():CheckLine(laser_source_pos, laser_ent_pair.npc.Position, 3)
        laser_ent_pair.laser:SetMaxDistance(laser_source_pos:Distance(endPos))
        laser_ent_pair.laser.CollisionDamage = 0
        laser_ent_pair.laser:SetColor(Color(0,0,0,1,0.89,0.92,0.81), 0, 1, false, false)
        laser_ent_pair.laser.Mass = 0
        laser_ent_pair.laser.DepthOffset = 200.0
        --Isaac.ConsoleOutput(tostring(laser_ent_pair.laser.DepthOffset))
        table.insert(coil_source:GetData()["Lasers"], laser_ent_pair)
        npc_target:GetData()[("CoilTagged"..tostring(coil_source:GetData()["CoilID"]))] = true
    end
end


--[[
    Helper function to adjust lasers to connect properly after an enemy moves
--]]
local function adjust_laser(laser_pair, coil_source)
    local laser_source_pos = Vector(coil_source.Position.X, coil_source.Position.Y-10)
    laser_pair.laser.Angle = (laser_pair.npc.Position - laser_source_pos):GetAngleDegrees()
    local _, endPos = Game():GetRoom():CheckLine(laser_source_pos, laser_pair.npc.Position, 3)
    laser_pair.laser:SetMaxDistance(laser_source_pos:Distance(endPos))
end


--[[--------------------------------------------------------

Callback functions below with dividers to separate
each monster by group or individual.

--]]--------------------------------------------------------


--[[
    NPC Update Function
--]]
function mod:NPCUpdate(npc)
    --[[ COIL ]]----------------------------------------------------------------------------------------------------
    if npc.Variant == MonsterVariants.COIL then -- Check if entity is coil
        npc.Position = npc:GetData()["StartPos"] -- anchor to position
        npc:GetSprite():Play("Idle")
        if npc:GetData()["AliveFrames"] > 8 then -- delay laser spawning
            local room_entities = Isaac.GetRoomEntities()
            for _,v in pairs(room_entities) do
                if v:IsEnemy() and not v:GetData()[("CoilTagged"..tostring(npc:GetData()["CoilID"]))] and v:GetData()["CoilBlacklist"] == nil then
                    addLaser(v, npc)
                end
            end
            for _,v in pairs(npc:GetData()["Lasers"]) do -- remove lasers from dead, or adjust them to follow entities
                if v.npc:IsDead() then
                    v.laser:Remove()
                else
                    adjust_laser(v, npc)
                end
            end
        else
            npc:GetData()["AliveFrames"] = npc:GetData()["AliveFrames"] + 1
        end
    end
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.NPCUpdate, 200)


--[[
    NPC Init Function
--]]
function mod:NPCInit(npc)

    --[[ COIL ]]----------------------------------------------------------------------------------------------------
    if npc.Variant == MonsterVariants.COIL then
        npc:GetData()["StartPos"] = npc.Position -- Get anchor position
        npc:GetData()["CoilID"] = math.random(100)
        npc:GetData()["Lasers"] = {}
        npc:GetData()["AliveFrames"] = 0
		npc:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_HIDE_HP_BAR | EntityFlag.FLAG_NO_TARGET) -- Same as grimaces
    end
	
	--[[ DUMPLINGS ]]-----------------------------------------------------------------------------------------------
	-- converts Dumplings with the old ID and ones from the other mod to the new one
	if isDumpling(npc.Variant) then
		newdump = Isaac.Spawn(800, npc.Variant - 2401, npc.SubType, npc.Position, npc.Velocity, nil)
		
		if npc:IsChampion() then
			newdump:MakeChampion(0, npc:GetChampionColorIdx(), true)
		end
		
		npc:Remove()
	end
    
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.NPCInit, 200)


--[[
    NPC Damage Function
--]]
function mod:NPCDamage(entity, amount, dmg_flags)
    -- Information to use for multiple enemies
    local npc = entity:ToNPC()
    
    --[[ COIL ]]----------------------------------------------------------------------------------------------------
    if npc.Variant == MonsterVariants.COIL then -- coils should not take damage of any kind
        return false -- how is this different to just making them have 0 max hitpoints?
    end
	
	--[[ RED TNT ]]----------------------------------------------------------------------------------------------------
    if npc.Variant == MonsterVariants.REDTNT then -- red tnt should not take damage since it explodes on collision
        return false
    end

end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.NPCDamage, 200)


--[[
    NPC Collision Function
--]]
function mod:NPCCollision(entity, collider, low)
    -- Information to use for multiple enemies
    local npc = entity:ToNPC()
	local room_index = Game():GetLevel():GetCurrentRoomIndex()
	
	--[[ RED TNT ]]-------------------------------------------------------------------------------------------------
	if npc.Variant == MonsterVariants.REDTNT then
		Isaac.Explode(npc.Position, npc, 100)
		npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		npc:GetSprite():Play("Blown")
		
		if RedTNTRoomRecord[room_index] ~= nil then
			for i,v in pairs(RedTNTRoomRecord[room_index]) do 
				if v == npc.Position then
					table.remove(RedTNTRoomRecord[room_index], i)
				end
			end
		end
    end
	
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.NPCCollision, 200)


--[[
    Called when player enters a new room
--]]
function mod:EnterNewRoom()
    local room_index = Game():GetLevel():GetCurrentRoomIndex()
    if Game():GetRoom():IsFirstVisit() then
	    local room_entities = Isaac.GetRoomEntities()
        local coil_table = {}
		local redtnt_table = {}
        for _,v in pairs(room_entities) do
            if v:IsEnemy() and v.Type.."."..v.Variant == "200.2406" then -- check if is coil
				table.insert(coil_table, v.Position)
            elseif v:IsEnemy() and v.Type.."."..v.Variant == "200.3400" then -- check if is red tnt
				table.insert(redtnt_table, v.Position)
			end
        end
        CoilRoomRecord[room_index] = coil_table
		RedTNTRoomRecord[room_index] = redtnt_table
    else
        if CoilRoomRecord[room_index] ~= nil then
            for _,v in pairs(CoilRoomRecord[room_index]) do
                Isaac.Spawn(200, 2406, 0, v, Vector.Zero, nil) -- respawn coils
            end
        end
		
		if RedTNTRoomRecord[room_index] ~= nil then
			for _,v in pairs(RedTNTRoomRecord[room_index]) do
				Isaac.Spawn(200, 3400, 0, v, Vector.Zero, nil) -- respawn red tnts
			end
		end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.EnterNewRoom)


--[[
   Called when player enters a new stage
--]]
function mod:EnterNewLevel()
    CoilRoomRecord = {} -- reset coil record upon new stage entry
	RedTNTRoomRecord = {}
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.EnterNewLevel)


--[[
    Some util functions
]]-- 
function AntiMonsterLib:GetPlayers()

    local players = {}

    for i = 1, Game():GetNumPlayers() do
        table.insert(players, Isaac.GetPlayer(i - 1))
    end

    return players

end


--[[
    Load the external files.
]]--
for _, v in pairs(monsters) do
    v.Init()
end