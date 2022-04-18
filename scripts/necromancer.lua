local this = {}
local game = Game()



local Settings = {
	MoveSpeed = 5.1,
	MoveSpeedIdle = 0.75,
	SpawnCooldown = 90,
	ReviveCooldown = 12,
	MaxRange = 400
}

local States = {
	Appear = 0,
	Moving = 1,
	HasReviveTarget = 2,
	Revive = 3,
	Spawn = 4
}

local necromancerSpawns = {}



function this:necromancerInit(entity)
	if entity.Variant == 2410 then
		local data = entity:GetData()
		
		entity:ToNPC()
		entity:AddEntityFlags(EntityFlag.FLAG_APPEAR)
		data.state = States.Appear
		data.reviveCooldown = Settings.ReviveCooldown
		data.place = Isaac:GetRandomPosition()
		
		local myRNG = RNG()
		myRNG:SetSeed(Random(), 831)
		data.bonyCooldown = (myRNG:RandomInt(Settings.SpawnCooldown / 2) + 1) + 15
		
		-- Remove any existing callback and add a new one so they don't execute code in it multiple times (it's here as well so Necromancers that aren't spawned as part of the room layout will still work)
		AntiMonsterLib:RemoveCallback(ModCallbacks.MC_POST_NPC_DEATH, this.necromancerInRoom)
		AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.necromancerInRoom)
	end
end



function this:necromancerUpdate(entity)
	if entity.Variant == 2410 then
		local sprite = entity:GetSprite()
		local data = entity:GetData()
		local room = game:GetRoom()
		
		
		function Lerp(first,second,percent)
			return (first + (second - first) * percent)
		end

		
		if data.state == States.Appear or data.state == nil then
			data.state = States.Moving


		elseif data.state == States.Moving or data.state == States.HasReviveTarget then
			entity:AnimWalkFrame("WalkHori", "WalkVert", 0.1)
			if not sprite:IsOverlayPlaying("Head") then
				sprite:PlayOverlay("Head", true)
			end
			
			if data.state == States.Moving then
				-- If there are valid entries in the table then go to revive state
				if data.reviveCooldown <= 0 then
					for i,v in pairs(necromancerSpawns) do
						if v ~= nil and (entity:GetChampionColorIdx() == ChampionColor.TRANSPARENT or entity.Pathfinder:HasPathToPos(v[4], false)) then -- Ghost champions can go to any of them
							data.state = States.HasReviveTarget
							data.reviveIndex = i
							data.reviveIdentifier = v[5]
						end
					end
					
				else
					data.reviveCooldown = data.reviveCooldown - 1
				end
				
				
				if entity.Position:Distance(data.place) < 3 or entity.Velocity:Length() < 1 or not entity.Pathfinder:HasPathToPos(data.place, false) then
					data.place = Isaac:GetRandomPosition()
				end
				entity.Pathfinder:FindGridPath(data.place, Settings.MoveSpeedIdle, 500, true)
				entity.Pathfinder:UpdateGridIndex() -- Seems to make them less jittery?


				if entity.Child == nil then
					-- Spawn Bony
					if data.bonyCooldown <= 0 then
						data.state = States.Spawn
						data.bonyCooldown = Settings.SpawnCooldown
						
					else
						data.bonyCooldown = data.bonyCooldown - 1
					end
				end

			elseif data.state == States.HasReviveTarget then
				-- Move where the enemy died
				if necromancerSpawns[data.reviveIndex] ~= nil and data.reviveIdentifier == necromancerSpawns[data.reviveIndex][5] then
					if entity.Position:Distance(necromancerSpawns[data.reviveIndex][4]) > 30 then
						-- If it doesn't have a direct path
						if game:GetRoom():CheckLine(entity.Position, necromancerSpawns[data.reviveIndex][4], 0, 0, false, false) == false
						and entity:GetChampionColorIdx() ~= ChampionColor.TRANSPARENT then -- Ghost champions can go to any of them
							entity.Pathfinder:FindGridPath(necromancerSpawns[data.reviveIndex][4], Settings.MoveSpeed / 6, 500, false)
							
						-- This stops them from sometimes not being able to revive enemies even though they're close enough
						else
							entity.Velocity = Lerp(entity.Velocity, (necromancerSpawns[data.reviveIndex][4] - entity.Position):Normalized() * Settings.MoveSpeed, 0.5)
						end
						
					else
						data.state = States.Revive
					end
				
				-- If it already got revived then return to move state
				else
					data.state = States.Moving
				end
			end

			
		elseif data.state == States.Revive or data.state == States.Spawn then
			entity.Velocity = Vector(0,0)

			if not sprite:IsPlaying("Revive") then
				sprite:Play("Revive", true)
				sprite:RemoveOverlay()
			end

			if sprite:IsEventTriggered("Revive") then
				if data.state == States.Revive then
					-- If it hasn't been revived yet then revive + remove it from the table
					if necromancerSpawns[data.reviveIndex] ~= nil and data.reviveIdentifier == necromancerSpawns[data.reviveIndex][5] then
						SFXManager():Play(SoundEffect.SOUND_SUMMONSOUND, 1, 0, false, 1, 0)

						local revived = Isaac.Spawn(necromancerSpawns[data.reviveIndex][1], necromancerSpawns[data.reviveIndex][2], necromancerSpawns[data.reviveIndex][3], Vector(entity.Position.X, entity.Position.Y + 15), Vector.Zero, entity)
						table.remove(necromancerSpawns, data.reviveIndex)
						data.reviveCooldown = Settings.ReviveCooldown
						
						-- Charmed / Friendly Necromancers create friendly enemies
						if (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then
							revived:AddCharmed(EntityRef(entity), -1)
						end
					end
				
				-- Spawn a Bony and set it as the Necromancer's child
				elseif data.state == States.Spawn then
					SFXManager():Play(SoundEffect.SOUND_SUMMONSOUND, 1, 0, false, 1, 0)
					entity.Child = Isaac.Spawn(EntityType.ENTITY_BONY, 0, 0, Vector(entity.Position.X, entity.Position.Y + 10), Vector.Zero, entity)
				end
			end
			
			if sprite:GetFrame() == 19 then -- IsFinished doesn't seem to work?
				data.state = States.Moving
			end
		end
	end
end



function this:necromancerInRoom(entity)
	if entity.Type < 1000 and entity.Type > 9 and not ((entity.Type == EntityType.ENTITY_BONY and entity.Variant == 0) or (entity.Type == EntityType.ENTITY_LITTLE_HORN and entity.Variant == 1)
	or (entity.Type == EntityType.ENTITY_RAG_MEGA and entity.Variant == 1) or (entity.Type == EntityType.ENTITY_GRUB and entity.Variant == 100 and entity.Parent ~= nil)
	or (entity.Type == EntityType.ENTITY_BIG_BONY and entity.Variant == 10)) then -- This is really messy, it should probably have a blacklist like Corpse Eaters do but I'm lazy
		local room = game:GetRoom()
		local getType = entity.Type
		local getVariant = entity.Variant
		local getSubType = entity.SubType
		
		-- Necromancers and Exorcists turn into Bonys when revived
		if (entity.Type == 200 and entity.Variant == 2410) or (entity.Type == EntityType.ENTITY_EXORCIST and entity.Variant == 0) then
			getType = EntityType.ENTITY_BONY
			getVariant = 0
			getSubType = 0
		
		-- Turn Cursed Globins into ones that don't split
		elseif entity.Type == 24 and entity.Variant == 3 then
			getSubType = 1
		end
		
		local ent_data = {getType, getVariant, getSubType, room:FindFreeTilePosition(entity.Position, 52), entity.Index}
		table.insert(necromancerSpawns, ent_data)
	end
end



function this:necromancerNewRoom()
	necromancerSpawns = {}
	AntiMonsterLib:RemoveCallback(ModCallbacks.MC_POST_NPC_DEATH, this.necromancerInRoom)
	
	-- Remove any existing callback and add a new one so they don't execute code in it multiple times
	for _,v in pairs(Isaac.GetRoomEntities()) do
		if v.Type == 200 and v.Variant == 2410 then
			AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.necromancerInRoom)
			break
		end
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.necromancerInit, 200)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.necromancerUpdate, 200)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, this.necromancerNewRoom)
end



return this