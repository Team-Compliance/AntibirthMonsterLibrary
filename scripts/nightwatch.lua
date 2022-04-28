local this = {}
local game = Game()



local Settings = {
	MoveSpeed = 2,
	RotateTimer = 85,
	FrontRange = 200,
	SideRange = 30,
	TransparencyTimer = 10
}

local States = {
	Appear = 0,
	Moving = 1,
	Alert = 2,
	AlertNoEffect = 3
}

local nightwatches = {}
local nightwatchEventPositions = {}
local nightwatchPaths = {}
local nightwatchRemoveEvent = {}
local nightwatchRemoveEventSavedPositions = {}



function nwLerp(first,second,percent)
	return (first + (second - first) * percent)
end



-- Get path positions
function getPaths(room_index)
	local level = Game():GetLevel()
	local roomDescriptor = level:GetCurrentRoomDesc()
	local roomConfigRoom = roomDescriptor.Data
	local spawnList = roomConfigRoom.Spawns

	nightwatchPaths[room_index] = {}

	for i = 0, spawnList.Size do
		if spawnList:Get(i) ~= nil then
			local roomConfigSpawn = spawnList:Get(i)

			for j = 0, 1, 0.1 do
				if roomConfigSpawn:PickEntry(j) ~= nil then
					local roomConfigEntry = roomConfigSpawn:PickEntry(j)
					
					if roomConfigEntry.Type == 970 and roomConfigEntry.Variant > 689 and roomConfigEntry.Variant < 696 then
						local pathData = {roomConfigEntry.Variant - 690, Vector(roomConfigSpawn.X, roomConfigSpawn.Y), math.floor(roomConfigEntry.Subtype / 16)}
						local alreadyHas = false
						local group = roomConfigEntry.Subtype - (math.floor(roomConfigEntry.Subtype / 16) * 16)

						if nightwatchPaths[room_index][group] ~= nil then
							if roomConfigEntry.Variant ~= 695 then
								for k,s in pairs(nightwatchPaths[room_index][group]) do
									if s[2].X == pathData[2].X and s[2].Y == pathData[2].Y then
										alreadyHas = true
									end
								end
							end

						-- Create a table for this group if it doesn't already have one
						else
							nightwatchPaths[room_index][group] = {}
						end
						
						if alreadyHas == false then
							table.insert(nightwatchPaths[room_index][group], pathData)
						end
					end
				end
			end
		end
	end
end

-- Get the event positions
function this:nightwatchGetPositions(Type, Variant, SubType, GridIndex, Seed)
	local room_index = game:GetLevel():GetCurrentRoomIndex()
	
	-- Create the table if it doesn't already exist
	if game:GetRoom():IsFirstVisit() then
		if nightwatchEventPositions[room_index] == nil then
			nightwatchEventPositions[room_index] = {}
			getPaths(room_index)
		end
	end

	if nightwatchEventPositions[room_index] ~= nil and Type == 969 and Variant == 8 then
		table.insert(nightwatchEventPositions[room_index], GridIndex)
	end
end

-- Get Nightwatch positions when first entering and respawn them if re-entering
function this:nightwatchNewRoom()
	local room_index = game:GetLevel():GetCurrentRoomIndex()
	
    if game:GetRoom():IsFirstVisit() then
        local nightwatch_table = {}

        for _,v in pairs(Isaac.GetRoomEntities()) do
			-- Get Nightwatches
            if v.Type == 842 then
				local nw_data = {v.SubType, v.Position}
				table.insert(nightwatch_table, nw_data)
			end
        end
		nightwatches[room_index] = nightwatch_table

    else
		-- Respawn Nightwatches
        if nightwatches[room_index] ~= nil then
			for _,v in pairs(nightwatches[room_index]) do
				Isaac.Spawn(842, 0, v[1], v[2], Vector.Zero, nil)
			end
        end
		
		-- Tag all appropriate entities with the remove tag when re-entering
		if nightwatchRemoveEventSavedPositions[room_index] ~= nil then
			for i,v in pairs(nightwatchRemoveEventSavedPositions[room_index]) do
				for _,e in pairs(Isaac.GetRoomEntities()) do
					if e.Position.X == v[2].X and e.Position.Y == v[2].Y then
						e:GetData().nwRemove = true
						table.remove(nightwatchRemoveEventSavedPositions[room_index], i)
					end
				end
			end
		end
    end
end

-- Clean the lists when entering a new floor
function this:nightwatchClearLists()
	nightwatchEventPositions = {}
	nightwatches = {}
	nightwatchPaths = {}
	nightwatchRemoveEvent = {}
	nightwatchRemoveEventSavedPositions = {}
end



-- Alerting
-- Grid events
function nightwatchGridEvent(Index)
	local gentity = game:GetRoom():GetGridEntity(Index)
	if gentity ~= nil then
		if gentity:GetType() == GridEntityType.GRID_ROCK and gentity.VarData == 1 then
			gentity:Destroy(true)
			
		elseif gentity:GetType() == GridEntityType.GRID_PIT and gentity.VarData == 1 then
			gentity:ToPit():MakeBridge(nil)
			
		elseif gentity:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gentity.State ~= 3 then
			gentity:ToPressurePlate():Reward()
			gentity.State = 3
			gentity:GetSprite():Play("Switched", true)
			
		elseif gentity:GetType() == GridEntityType.GRID_TELEPORTER then
			if gentity.State == 2 then
				gentity.State = 1
			else
				gentity.State = 2
			end
		end
	end
end

function nightwatchAlert()
	local room = game:GetRoom()
	local room_index = game:GetLevel():GetCurrentRoomIndex()

	-- Trigger grid events
	if nightwatchEventPositions[room_index] ~= nil then
		for _,v in pairs(nightwatchEventPositions[room_index]) do
			nightwatchGridEvent(v + 1)
			nightwatchGridEvent(v - 1)
			nightwatchGridEvent(v + room:GetGridWidth())
			nightwatchGridEvent(v - room:GetGridWidth())
		end
	end

	for _,v in pairs(Isaac.GetRoomEntities()) do
		-- Alert all other Nightwatches
		if v.Type == 842 and v:GetData().state ~= States.Alert and v:GetData().state ~= States.AlertNoEffect then
			v:GetData().state = States.AlertNoEffect
		
		-- Spawn event entities
		elseif v.Type == 1000 and v.Variant == 120 and v:ToEffect().State == 8 then
			v:Die()
		end
		
		if v:GetData().nwRemove == true then
			if v.Type == 5 and v.Variant == 100 then
				v:ToPickup():Morph(1000, EffectVariant.POOF01, 0, false, true, true)
			end
			
			v:Remove()
			Isaac.Spawn(1000, EffectVariant.POOF01, 0, v.Position, Vector.Zero, v)
		end
	end
end



-- Spotlight
function this:spotlightUpdate(spotlight)
	if spotlight.Parent ~= nil then
		local data = spotlight:GetData()
		local sprite = spotlight:GetSprite()
		
		sprite.Offset = Vector(0, -24)
		
		if data.targetRotation ~= nil then
			spotlight:FollowParent(spotlight.Parent)

			if sprite.Rotation ~= data.targetRotation then
				sprite.Rotation = nwLerp(sprite.Rotation, data.targetRotation, 0.25)
			end
		end
		
	else
		spotlight:Remove()
	end
end



function this:nightwatchInit(entity)
	local data = entity:GetData()

	entity.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
	entity.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
	entity:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_APPEAR | EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_PLAYER_CONTROL)
	
	data.state = States.Appear
	data.rotateTimer = Settings.RotateTimer - 20
end

function this:nightwatchUpdate(entity)
	local sprite = entity:GetSprite()
	local data = entity:GetData()
	local target = game:GetNearestPlayer(entity.Position)
	local room_index = game:GetLevel():GetCurrentRoomIndex()
	
	
	-- Get facing direction
	if data.facing == nil then
		if entity.SubType % 10 == 0 then
			data.facing = "Left"
		elseif entity.SubType % 10 == 1 then
			data.facing = "Up"
		elseif entity.SubType % 10 == 2 then
			data.facing = "Right"
		else
			data.facing = "Down"
		end
	end
	
	-- Get movement type
	if data.movetype == nil then
		if entity.SubType - (entity.SubType % 10) == 0 then
			data.movetype = "Bounce"
		elseif entity.SubType - (entity.SubType % 10) == 30 then
			data.movetype = "Rotate Clockwise"
		elseif entity.SubType - (entity.SubType % 10) == 40 then
			data.movetype = "Rotate CounterClockwise"
		elseif entity.SubType - (entity.SubType % 10) == 60 then
			data.movetype = "Path"
		elseif entity.SubType - (entity.SubType % 10) == 70 then
			data.movetype = "Flip"
		else
			data.movetype = "Stationary"
		end
	end


	-- Spotlight detection range
	function inSpotlight()
		local checkmode = 3
		if game:GetRoom():GetType() == RoomType.ROOM_DUNGEON then -- Fix for crawlspaces
			checkmode = 2
		end
		
		if game:GetRoom():CheckLine(entity.Position, target.Position, checkmode, 0, false, false)
		and not (target:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_DARK_ARTS) or target:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_CAMO_UNDIES)) then
			if data.facing == "Left" or data.facing == "Right" then
				if entity.Position.Y <= target.Position.Y + Settings.SideRange and entity.Position.Y >= target.Position.Y - Settings.SideRange then
					if data.facing == "Left" and target.Position.X > (entity.Position.X - Settings.FrontRange) and target.Position.X < entity.Position.X
					or data.facing == "Right" and target.Position.X < (entity.Position.X + Settings.FrontRange) and target.Position.X > entity.Position.X then
						return true
					end
				end
				
			elseif data.facing == "Up" or data.facing == "Down" then
				if entity.Position.X <= target.Position.X + Settings.SideRange and entity.Position.X >= target.Position.X - Settings.SideRange then
					if data.facing == "Up" and target.Position.Y > (entity.Position.Y - Settings.FrontRange) and target.Position.Y < entity.Position.Y
					or data.facing == "Down" and target.Position.Y < (entity.Position.Y + Settings.FrontRange) and target.Position.Y > entity.Position.Y then
						return true
					end
				end
			end
		end
	end
	
	
	-- Transparency
	if data.transTimer ~= nil then -- trans rights
		if data.transTimer <= 0 then
			sprite.Color = Color(1,1,1, 1)
			data.transTimer = nil
		else
			sprite.Color = Color(1,1,1, 0.5)
			data.transTimer = data.transTimer - 1
		end
	end
	
	
	-- If there are remove on alert events then tag the appropriate entities
	if nightwatchRemoveEvent[room_index] ~= nil then
		for _,e in pairs(Isaac:GetRoomEntities()) do
			for i,v in pairs(nightwatchRemoveEvent[room_index]) do
				if e.Position.X == v.X and e.Position.Y == v.Y and (e.Type > 9 or e.Type == 5) and e.Type < 1000 and e.Type ~= 969 and e.Type ~= 970 then
					e:GetData().nwRemove = true
					table.remove(nightwatchRemoveEvent[room_index], i)
				end
			end
		end
	end
	
	
	-- States
	if data.state == States.Appear or data.state == nil then
		data.state = States.Moving
		
	elseif data.state == States.Moving then
		if not sprite:IsPlaying("Walk" .. data.facing) then
			sprite:Play("Walk" .. data.facing, true)
		end
		
		-- Spotlight
		if entity.Child == nil then
			entity.Child = Isaac.Spawn(1000, 842, 0, entity.Position, Vector.Zero, entity)
			entity.Child.Parent = entity

			entity.Child:GetSprite():Play("FadeIn", true)
			entity.Child:GetData().targetRotation = 0
		end

		if inSpotlight() == true then
			data.state = States.Alert
		end


		-- Movement
		if data.movetype == "Bounce" or data.movetype == "Path" then
			if not data.vector then
				if data.facing == "Left" then
					data.vector = Vector(-Settings.MoveSpeed, 0)
				elseif data.facing == "Up" then
					data.vector = Vector(0, -Settings.MoveSpeed)
				elseif data.facing == "Right" then
					data.vector = Vector(Settings.MoveSpeed, 0)
				elseif data.facing == "Down" then
					data.vector = Vector(0, Settings.MoveSpeed)
				end

			else
				local angleDegrees = entity.Velocity:GetAngleDegrees()
						
				if angleDegrees > -45 and angleDegrees < 45 then
					data.facing = "Right"
				elseif angleDegrees >= 45 and angleDegrees <= 135 then
					data.facing = "Down"
				elseif angleDegrees < -45 and angleDegrees > -135 then
					data.facing = "Up"
				else
					data.facing = "Left"
				end
			end
			
			
			if data.delay then
				data.delay = data.delay - 1
					
				if data.delay <= 0 then
					data.delay = nil
				end
			end


			if not data.delay then
				if entity:CollidesWithGrid() then
					if data.facing == "Up" or data.facing == "Down" then
						data.vector = Vector(data.vector.X, -data.vector.Y)
						
					elseif data.facing == "Left" or data.facing == "Right" then
						data.vector = Vector(-data.vector.X, data.vector.Y)
					end
					
					data.delay = 7
				end
			end
				
				
			if data.movetype == "Path" then
				if nightwatchPaths[room_index] ~= nil and nightwatchPaths[room_index][entity.Variant] ~= nil then
					for _,v in pairs(nightwatchPaths[room_index][entity.Variant]) do
						if entity.Position:Distance(Vector((v[2].X + 2) * 40, (v[2].Y + 4)  * 40)) <= 7 then
							if v[1] == 0 then -- Left
								data.vector = Vector(-Settings.MoveSpeed, 0)
							elseif v[1] == 1 then -- Up
								data.vector = Vector(0, -Settings.MoveSpeed)
							elseif v[1] == 2 then -- Right
								data.vector = Vector(Settings.MoveSpeed, 0)
							elseif v[1] == 3 then -- Down
								data.vector = Vector(0, Settings.MoveSpeed)
							elseif v[1] == 5 then -- Change group
								if entity.Variant ~= v[3] then
									entity.Variant = v[3]
								end
							else -- Stop
								data.vector = Vector(0,0)
							end
						end
					end
				end
			end
			
			entity.Velocity = nwLerp(entity.Velocity, data.vector, 0.25)
			
			
		elseif data.movetype == "Rotate Clockwise" or data.movetype == "Rotate CounterClockwise" or data.movetype == "Flip" then
			if data.rotateTimer <= 0 then
				if data.movetype == "Rotate Clockwise" then
					if data.facing == "Left" then
						data.facing = "Up"
					elseif data.facing == "Up" then
						data.facing = "Right"
					elseif data.facing == "Right" then
						data.facing = "Down"
					elseif data.facing == "Down" then
						data.facing = "Left"
					end
					
				elseif data.movetype == "Rotate CounterClockwise" then
					if data.facing == "Left" then
						data.facing = "Down"
					elseif data.facing == "Down" then
						data.facing = "Right"
					elseif data.facing == "Right" then
						data.facing = "Up"
					elseif data.facing == "Up" then
						data.facing = "Left"
					end
					
				elseif data.movetype == "Flip" then
					if data.facing == "Left" then
						data.facing = "Right"
					elseif data.facing == "Up" then
						data.facing = "Down"
					elseif data.facing == "Right" then
						data.facing = "Left"
					elseif data.facing == "Down" then
						data.facing = "Up"
					end
				end
				data.rotateTimer = Settings.RotateTimer
				
			else
				data.rotateTimer = data.rotateTimer - 1
			end
		end
		
		-- Spotlight directions
		if data.facing == "Left" then
			entity.Child:GetData().targetRotation = 90
			
		elseif data.facing == "Up" then
			if entity.Child:GetData().targetRotation == -90 then
				entity.Child:GetSprite().Rotation = 270
			end
			entity.Child:GetData().targetRotation = 180
			
		elseif data.facing == "Right" then
			if entity.Child:GetData().targetRotation == 180 then
				entity.Child:GetSprite().Rotation = -180
			end
			entity.Child:GetData().targetRotation = -90

		elseif data.facing == "Down" then
			entity.Child:GetData().targetRotation = 0
		end

		
	elseif data.state == States.Alert or data.state == States.AlertNoEffect then
		if not sprite:IsPlaying("Trigger" .. data.facing) then
			sprite:Play("Trigger" .. data.facing, true)
			entity.Velocity = Vector(0,0)
		end
	end


	-- Alerted
	if sprite:IsEventTriggered("Shoot") and data.state == States.Alert then
		entity:PlaySound(Isaac.GetSoundIdByName("Nightwatch Alert"), 1, 0, false, 1)
		
		-- Alert events
		nightwatchAlert()
		nightwatches[room_index] = nil
		nightwatchEventPositions[room_index] = nil
		nightwatchRemoveEvent[room_index] = nil
		nightwatchRemoveEventSavedPositions[room_index] = nil
		
		-- Projectile
		local params = ProjectileParams()
		params.Variant = 106
		params.FallingSpeedModifier = -4.5
		params.FallingAccelModifier = 0.5
		entity:FireProjectiles(entity.Position, (target.Position - entity.Position):Normalized() * 11, 0, params)
	end

	if sprite:GetFrame() == 36 then
		if entity.Child ~= nil then
			entity.Child:GetSprite():Play("FadeOut", true)
		end
	elseif sprite:GetFrame() == 40 then -- IsFinished doesn't seem to work?
		Isaac.Spawn(1000, EffectVariant.POOF01, 0, entity.Position, Vector.Zero, entity)
		entity:Remove()
	end
end

-- Alert the Nightwatch if the player touches it
function this:nightwatchCollide(entity, target, cock) -- TODO: Boomerang shouldn't be able to move them but ignoring collision here doesn't seem to work
	if entity:GetData().state == States.Moving and target.Type == EntityType.ENTITY_PLAYER then
		entity:GetData().state = States.Alert
	end
end

-- Turn transparent when hit
function this:nightwatchHit(target, damageAmount, damageFlags, damageSource, damageCountdownFrames)
	target:GetData().transTimer = Settings.TransparencyTimer
	return false
end



-- Projectile
function this:lanternInit(lantern)
	lantern:GetSprite():Play("Move")
	lantern:AddProjectileFlags(ProjectileFlags.FIRE_SPAWN)
end

function this:lanternUpdate(lantern)
	if lantern:IsDead() then
		SFXManager():Play(SoundEffect.SOUND_GLASS_BREAK, 1, 0, false, 1, 0)
		Isaac.Spawn(EntityType.ENTITY_FIREPLACE, 10, 0, lantern.Position, Vector.Zero, nil)
	end
end

-- On projectile hitting target
function this:lanternCollide(lantern, cunt, cum)
	SFXManager():Play(SoundEffect.SOUND_GLASS_BREAK, 1, 0, false, 1, 0)
	SFXManager():Play(SoundEffect.SOUND_FIREDEATH_HISS, 1, 0, false, 1, 0)
	Isaac.Spawn(EntityType.ENTITY_FIREPLACE, 10, 0, lantern.Position, Vector.Zero, nil)
	lantern:Kill()
end



-- Spawn entities that are tagged with the remove on alert event and add their position to a table
function this:removeEventSpawns(entity)
	if entity:ToEffect().State == 7 then
		local room_index = game:GetLevel():GetCurrentRoomIndex()
		
		if nightwatchRemoveEvent[room_index] == nil then
			nightwatchRemoveEvent[room_index] = {}
		end
		table.insert(nightwatchRemoveEvent[room_index], Vector(entity.Position.X, entity.Position.Y))

		entity:Die()
		if entity.SubType == EntityType.ENTITY_SHOPKEEPER or entity.SubType == EntityType.ENTITY_FIREPLACE then
			Isaac.Spawn(1000, EffectVariant.POOF01, 0, entity.Position, Vector.Zero, entity)
		end
		SFXManager():Stop(SoundEffect.SOUND_SUMMONSOUND)
	end
end

-- Save the position of pickups that should get removed on Nightwatch alert so the tag can be re-applied when re-entering the room
function this:removeEventSavePos(entity)
	if entity:GetData().nwRemove == true then
		local room_index = game:GetLevel():GetCurrentRoomIndex()
		
		if nightwatchRemoveEventSavedPositions[room_index] ~= nil then
			if entity.Touched ~= true then
				local data = {GetPtrHash(entity), entity.Position}
				local alreadyHas = false
				
				for _,v in pairs(nightwatchRemoveEventSavedPositions[room_index]) do
					if v[1] == GetPtrHash(entity) then
						alreadyHas = true
						v[2] = entity.Position
					end
				end
				
				if alreadyHas == false then
					table.insert(nightwatchRemoveEventSavedPositions[room_index], data)
				end
				
			else
				for i,v in pairs(nightwatchRemoveEventSavedPositions[room_index]) do
					if v[1] == GetPtrHash(entity) then
						table.remove(nightwatchRemoveEventSavedPositions[room_index], i)
					end
				end
			end
			
		else
			nightwatchRemoveEventSavedPositions[room_index] = {}
		end
	end
end



function this:Init()
	AntiMonsterLib:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, this.nightwatchGetPositions)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, this.nightwatchClearLists)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, this.nightwatchNewRoom)
	
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, this.spotlightUpdate, 842)
	
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.nightwatchInit, 842)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.nightwatchUpdate, 842)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, this.nightwatchCollide, 842)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, this.nightwatchHit, 842)

	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, this.lanternInit, 106)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, this.lanternUpdate, 106)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, this.lanternCollide, 106)
	
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, this.removeEventSpawns, 120)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, this.removeEventSavePos)
end



return this