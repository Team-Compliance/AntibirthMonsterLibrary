--[[ TODO ]]--
--[[
	- Make Carrion Riders only shoot when their line of sight isn't blocked by anything (HasPathToPos doesn't ignore pits)
	- Make Carrion Riders face you when they shoot (would have to be a really dumb system because of how the animations are)
	- Make Carrion Riders shoot at their enemy target if charmed/friendly
	- Make charmed (not including friendly) Corpse Eaters leave behind creep the player can walk on (spawning player creep makes them hurt themselves)
	- Make appear animation work for both head and body
	- Make friendly Corpse Eaters not do the chomp effects when colliding with other friendly enemies
	- Bestiary entry for them doesn't work for me even though it should?
	- Figure out a better way to stop them from getting too long / being headless so you can spawn them next to each other properly
	- Make them more aggressive?
]]--



local this = {}
local game = Game()



local CorpseEater = {
	BASE_HUNGER = 30,
	GIVE_UP_TIME = 90,
	MAX_HEALTH_MULTIPLIER = 2.5,
	TARGET_DETECTION_RANGE = 208,
	GIVE_UP_RANGE = 312,
	CHOMP_DAMAGE = 40,
	CHOMP_COOLDOWN = 10,
	CREEP_LENGTH = 120,
	BONY_COOLDOWN = 25,
	BONY_RANGE = 208,
	BONY_SHOTSPEED = 11
}



-- Don't target these entities
function CorpseEaterBlacklist(target)
	if
	target.Type == EntityType.ENTITY_FLY or
	target.Type == EntityType.ENTITY_ATTACKFLY or
	(target.Type == EntityType.ENTITY_SUCKER and target.Variant > 3) or -- Bulbs, Blood fly (can't collide, also it's evil)
	target.Type == EntityType.ENTITY_SPIDER or
	target.Type == EntityType.ENTITY_DIP or
	target.Type == EntityType.ENTITY_WIZOOB or
	target.Type == EntityType.ENTITY_RING_OF_FLIES or
	target.Type == EntityType.ENTITY_BONY or
	target.Type == EntityType.ENTITY_DART_FLY or
	target.Type == EntityType.ENTITY_BLACK_BONY or
	target.Type == EntityType.ENTITY_SWARM or
	target.Type == EntityType.ENTITY_RED_GHOST or
	target.Type == EntityType.ENTITY_MOMS_DEAD_HAND or
	target.Type == EntityType.ENTITY_CORN_MINE or
	target.Type == EntityType.ENTITY_HUSH_FLY or
	(target.Type == EntityType.ENTITY_LITTLE_HORN and target.Variant == 1) or -- Dark Ball, can't collide
	target.Type == EntityType.ENTITY_PORTAL or -- can't collide with them
	target.Type == EntityType.ENTITY_BISHOP or
	target.Type == EntityType.ENTITY_WILLO or -- can't collide
	target.Type == EntityType.ENTITY_STRIDER or
	target.Type == EntityType.ENTITY_POLTY or
	target.Type == EntityType.ENTITY_FLY_BOMB or
	target.Type == EntityType.ENTITY_BIG_BONY or
	target.Type == EntityType.ENTITY_WILLO_L2 or -- can't collide
	target.Type == EntityType.ENTITY_REVENANT or
	target.Type == EntityType.ENTITY_ARMYFLY or
	target.Type == EntityType.ENTITY_DRIP or
	target.Type == EntityType.ENTITY_NEEDLE and target.Variant == 1 or -- Pasty
	target.Type == EntityType.ENTITY_DUST or
	target.Type == EntityType.ENTITY_SWARM_SPIDER or
	target.Type == EntityType.ENTITY_CULTIST or -- Mainly for Purple Cultists so they can revive as many things for them as possible
	target.Type == EntityType.ENTITY_SHADY or
	target.Type == EntityType.ENTITY_CLICKETY_CLACK
	then
		return false
	else
		return true
	end
end



function this:CorpseEaterInit(entity)
	if entity.Variant == 100 or entity.Variant == 101 then
		local data = entity:GetData()
		local sprite = entity:GetSprite()
		local level = Game():GetLevel()
		local stage = level:GetStage()

		entity.Position = entity.Position + Vector(15,0) -- Makes them spawn more centered on the tile
		
		-- Set variables
		local myRNG = RNG()
		myRNG:SetSeed(Random(), 239)
		data.CurrentHunger = myRNG:RandomInt(CorpseEater.BASE_HUNGER)

		entity.CollisionDamage = 0
		data.MaxHp = entity.MaxHitPoints * CorpseEater.MAX_HEALTH_MULTIPLIER -- The maximum hp they can have from eating enemies
		data.ChompCooldown = CorpseEater.CHOMP_COOLDOWN
		data.Creepy = 0
		
		if entity.Variant == 101 then
			entity.ProjectileCooldown = CorpseEater.BONY_COOLDOWN
		end

		data.altSkin = ""
		if (stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
			data.altSkin = "_gehenna"
		elseif (stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE then
			data.altSkin = "_corpse"
		end


		-- Set spritesheet
		if data.altSkin ~= "" then
			sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/239.100_corpse_eater" .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(1, "gfx/monsters/repentance/239.100_corpse_eater_body" .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(2, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(3, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
			sprite:LoadGraphics()
		end
	end
end



function this:CorpseEaterUpdate(entity)
	if entity.Variant == 100 or entity.Variant == 101 then
		local data = entity:GetData()
		local target = entity.Target
		local sprite = entity:GetSprite()
		local level = Game():GetLevel()


		-- New target
		function getTarget()
			for i,others in pairs(Isaac.FindInRadius(entity.Position, CorpseEater.TARGET_DETECTION_RANGE, EntityPartition.ENEMY)) do
				if others:IsVulnerableEnemy() and not (others.Type == EntityType.ENTITY_GRUB and (others.Variant == 100 or others.Variant == 101))
				and entity.Pathfinder:HasPathToPos(others.Position, true) and CorpseEaterBlacklist(others) then
					entity.Target = others
					data.CurrentHunger = CorpseEater.GIVE_UP_TIME
				end
			end
		end

		-- Don't target enemies it can't kill
		if target ~= nil then
			if not target:IsVulnerableEnemy() or not entity.Pathfinder:HasPathToPos(target.Position, true) or target:IsDead()
			or entity.Position:Distance(target.Position) > CorpseEater.GIVE_UP_RANGE then -- Make them not stick to one target they can't get for too long
				getTarget()
			end
		end
		
		
		-- Cooldowns
		-- Target switching cooldown
		if data.CurrentHunger > 0 then
			data.CurrentHunger = data.CurrentHunger - 1
		else
			getTarget()
		end
		
		-- Chomp cooldown
		if data.ChompCooldown > 0 then
			data.ChompCooldown = data.ChompCooldown - 1
		end
		
		-- Creep Length
		if data.Creepy > 0 then
			data.Creepy = data.Creepy - 1
			
			if entity:IsFrame(4, 0) then
				local creepType = EffectVariant.CREEP_RED
				if entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then -- Charmed ones take damage from their own creep even with the spawner entity set correctly...
					creepType = EffectVariant.PLAYER_CREEP_RED
				end
				
				local creep = Isaac.Spawn(1000, creepType, 0, entity.Position, Vector(0,0), entity):ToEffect()
				creep.Scale = 1.1
				creep:SetTimeout(45)
			end
		end
		
		
		-- Stats
		-- Increased speed
		entity.Velocity = entity.Velocity * 1.03

		-- Make sure they don't get too tanky
		if entity.MaxHitPoints > data.MaxHp then
			entity.MaxHitPoints = data.MaxHp
		end
		
		
		-- Body segments
		-- Spawn the body if it doesn't already have one
		if entity.Parent == nil and entity.Child == nil and entity.FrameCount <= 1 then
			Isaac.Spawn(EntityType.ENTITY_GRUB, 100, 0, entity.Position - Vector(30, 0), Vector(0,0), nil):GetData().headIndex = entity.Index
			
		elseif entity.Parent == nil and entity.Child == nil and entity.FrameCount > 1 then
			entity:Remove() -- Have to do this for Friendly Ball to not create headless/bodyless Corpse Eaters, hopefully won't cause other issues

		-- Prevent them from getting longer than they should
		elseif entity.Parent ~= nil and entity.Child ~= nil then
			entity.Child:Remove()

		-- Make the body always appear under the head
		elseif entity.Parent ~= nil and entity.Child == nil then
			entity.DepthOffset = entity.Parent.DepthOffset - 10
			
			if entity.Parent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then -- Friendly Ball bullshit again, they don't get the visuals until they take damage but otherwise they work
				entity:AddCharmed(EntityRef(entity.Parent), -1)
			end
		end
		
		
		-- Carrion Rider
		if entity.Variant == 101 then
			if entity.Parent == nil and entity.Child ~= nil then
				local player = game:GetNearestPlayer(entity.Position)
				
				if entity.ProjectileCooldown > 0 then
					entity.ProjectileCooldown = entity.ProjectileCooldown - 1
					
					
					-- Reset head layers
					if entity.ProjectileCooldown == 14 or data.headFlip ~= sprite.FlipX then
						for i = 0, 5 do						
							sprite:ReplaceSpritesheet(i + 3, "")
						end
						sprite:ReplaceSpritesheet(3, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
						sprite:LoadGraphics()
					end
				end
				
				if entity.Position:Distance(player.Position) <= CorpseEater.BONY_RANGE and entity.ProjectileCooldown <= 0 -- TODO: make them only shoot if they have direct line of sight
				and not (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then -- Charmed ones don't get a target so I don't know how to make them shoot at other enemies
					-- Projectile
					local params = ProjectileParams()
					params.Variant = ProjectileVariant.PROJECTILE_BONE

					entity:FireProjectiles(entity.Position,(player.Position - entity.Position):Normalized() * CorpseEater.BONY_SHOTSPEED, 0, params)
					entity:PlaySound(SoundEffect.SOUND_SCAMPER, 1.25, 0, false, 1)

					entity.ProjectileCooldown = CorpseEater.BONY_COOLDOWN
					
					
					-- Change head direction (this was too much effort)
					local angleDegrees = (player.Position - entity.Position):Normalized():GetAngleDegrees()
					local angle = 3
					
					if angleDegrees > -45 and angleDegrees < 45 then -- Get angle for Bony head
						angle = 6 -- Right
					elseif angleDegrees >= 45 and angleDegrees <= 135 then
						angle = 7 -- Down
					elseif angleDegrees < -45 and angleDegrees > -135 then
						angle = 5 -- Up
					else
						angle = 4 -- Left
					end
					
					if sprite.FlipX == true then
						data.headFlip = true
						if angle == 6 then angle = 4
						elseif angle == 4 then angle = 6 end
					else
						data.headFlip = false -- Really dumb way to make sure they don't face the opposite direction from you when their Corpse Eater turns around
					end
					
					for i = 0, 5 do						
						sprite:ReplaceSpritesheet(i + 3, "")
					end
					sprite:ReplaceSpritesheet(angle, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
					sprite:LoadGraphics()
				end
			end
		end
	end
end



function this:CorpseEaterCollision(entity, target, cum)
	if entity.Variant == 100 or entity.Variant == 101 then
		local data = entity:GetData()
		local sprite = entity:GetSprite()		
	

		if target.Type == EntityType.ENTITY_PLAYER then
			target:TakeDamage(2, DamageFlag.DAMAGE_CRUSH, EntityRef(entity), 0)
			
		elseif CorpseEaterIsFriendly(entity, target) and target:IsVulnerableEnemy() and not target:IsDead() and data.ChompCooldown <= 0
		and not ((target.Type == EntityType.ENTITY_CULTIST and target.Variant == 0) or (target.Type == EntityType.ENTITY_VIS and target.Variant == 22)) -- Ignore Cultists so they revive things for them and ignore Chubber projectiles
		and entity.Parent == nil and not (entity:HasEntityFlags(EntityFlag.FLAG_FREEZE) or entity:HasEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE)) then
			target:TakeDamage(CorpseEater.CHOMP_DAMAGE, DamageFlag.DAMAGE_CRUSH, EntityRef(entity), 0)
			data.ChompCooldown = CorpseEater.CHOMP_COOLDOWN
			
			
			-- Effects
			local lessFullfilling = false

			if CorpseEaterGetEffect(target) == "small" then -- Make this better?
				entity:PlaySound(SoundEffect.SOUND_MEAT_IMPACTS, 1, 0, false, 1)
				Isaac.Spawn(1000, 2, 0, target.Position, Vector(0,0), nil)
				lessFullfilling = true
				
			elseif CorpseEaterGetEffect(target) == "poop" then
				Isaac.Spawn(1000, 43, 0, target.Position, Vector(0,0), nil)
				entity:PlaySound(SoundEffect.SOUND_PLOP, 0.75, 0, false, 1)
				data.ProjectileType = ProjectileVariant.PROJECTILE_PUKE
				lessFullfilling = true
				
			elseif CorpseEaterGetEffect(target) == "bone" then
				entity:PlaySound(SoundEffect.SOUND_BONE_HEART, 0.75, 0, false, 1.1)
				data.ProjectileType = ProjectileVariant.PROJECTILE_BONE
				lessFullfilling = true
			
			elseif CorpseEaterGetEffect(target) == "ghost" then
				entity:PlaySound(SoundEffect.SOUND_SKIN_PULL, 0.9, 0, false, 1.1)
				lessFullfilling = true
			
			elseif CorpseEaterGetEffect(target) == "stone" then
				entity:PlaySound(SoundEffect.SOUND_STONE_IMPACT, 1, 0, false, 1)
				data.ProjectileType = ProjectileVariant.PROJECTILE_ROCK
				lessFullfilling = true
				
			else
				Isaac.Spawn(1000, 16, 4, target.Position, Vector(0,0), nil)
				entity:PlaySound(SoundEffect.SOUND_MEATY_DEATHS, 0.75, 0, false, 1)
				lessFullfilling = false
			end
			

			-- If consumed
			if target:HasMortalDamage() then
				target:AddEntityFlags(EntityFlag.FLAG_EXTRA_GORE)


				-- Less fullfilling ones
				if lessFullfilling == true then
					entity:PlaySound(SoundEffect.SOUND_SMB_LARGE_CHEWS_4, 1, 0, false, 1)
					
					
					-- Projectiles
					if CorpseEaterGetEffect(target) == "bone" or CorpseEaterGetEffect(target) == "poop" or CorpseEaterGetEffect(target) == "stone" then
						local params = ProjectileParams()
						params.ChangeVelocity = 2
						params.Variant = data.ProjectileType

						local countRNG = RNG()
						countRNG:SetSeed(Random(), 239)
						local ProjectileCount = countRNG:RandomInt(4) + 5

						for i = 1, ProjectileCount do						
							entity:FireBossProjectiles(1, target.Position, 2.5, params)
						end
					
					-- Small enemies and ghosts
					else
						entity.MaxHitPoints = entity.MaxHitPoints + math.ceil(target.MaxHitPoints / 3)
						entity.HitPoints = entity.HitPoints + math.ceil(target.MaxHitPoints / 3)
						data.CurrentHunger = math.floor(target.MaxHitPoints / 2)
					end
					
					
				-- Yummy ones
				else
					entity.MaxHitPoints = entity.MaxHitPoints + math.ceil(target.MaxHitPoints / 2)
					entity.HitPoints = entity.HitPoints + math.ceil(target.MaxHitPoints / 2)
					data.CurrentHunger = target.MaxHitPoints -- + CorpseEater.BASE_HUNGER
					data.Creepy = CorpseEater.CREEP_LENGTH
					
					
					-- Effects
					Isaac.Spawn(1000, 16, 3, target.Position, Vector(0,0), nil)
					entity:PlaySound(SoundEffect.SOUND_SMB_LARGE_CHEWS_4, 1.5, 0, false, 1)
					--Isaac.Spawn(1000, 49, 0, Vector(entity.Position.X, entity.Position.Y - 40), Vector(0,0), nil) -- HP up indicator
					
					-- Set skin to bloody one
					sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/239.100_corpse_eater_2" .. data.altSkin .. ".png")
					sprite:LoadGraphics()
					
					
					-- Projectiles
					local params = ProjectileParams()
					params.ChangeVelocity = 2

					local countRNG = RNG()
					countRNG:SetSeed(Random(), 239)
					local ProjectileCount = countRNG:RandomInt(6) + 7

					for i = 1, ProjectileCount do
						local projRNG = RNG()
						projRNG:SetSeed(Random(), 239)
						local IsBone = projRNG:RandomInt(6)
						
						if IsBone <= 1 then
							direction = target.Position
						elseif IsBone > 1 and IsBone < 4 then
							direction = game:GetNearestPlayer(entity.Position).Position
						else
							direction = entity.Position
						end
						
						if IsBone == 3 then
							params.Variant = ProjectileVariant.PROJECTILE_BONE
						else
							params.Variant = ProjectileVariant.PROJECTILE_NORMAL
						end
						
						entity:FireBossProjectiles(1, direction, 2.5, params)
					end
				end
			end
		end
	end
end



function this:CorpseEaterDeath(entity)
	if entity.Variant == 100 or entity.Variant == 101 then
		-- Bony from Carrion Rider
		if entity.Variant == 101 then
			Isaac.Spawn(227, 0, 0, entity.Position, Vector(0,0), nil)
		end

		-- Remove the maggots that are spawned on death
		for i, maggots in ipairs(Isaac.GetRoomEntities()) do
			if maggots.SpawnerType == EntityType.ENTITY_GRUB and (maggots.SpawnerVariant == 100 or maggots.SpawnerVariant == 101) then
				if maggots.Type == EntityType.ENTITY_MAGGOT or maggots.Type == EntityType.ENTITY_CHARGER or maggots.Type == EntityType.ENTITY_SPITTY then
					maggots:Remove()
				end
			end
		end
	end
end



-- Dumb bullshit for charmed and friendly Corpse Eaters
function CorpseEaterIsFriendly(entity, target)
	if target.Type == EntityType.ENTITY_GRUB and (target.Variant == 100 or target.Variant == 101) then
		if not (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and target:GetData().headIndex ~= entity.Index -- Non-friendly Corpse Eaters hurting charmed/baited ones
		and (target:HasEntityFlags(EntityFlag.FLAG_CHARM) or target:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) or target:HasEntityFlags(EntityFlag.FLAG_BAITED)) then
			return true

		elseif (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and not target:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and target:GetData().headIndex ~= entity.Index then -- Charmed Corpse Eaters hurting non-friendly ones
			return true
			
		else
			return false
		end
	else
		return true
	end
end



-- Determine which effects to use for chomping
function CorpseEaterGetEffect(target)
	if
	target.Type == EntityType.ENTITY_FLY or
	target.Type == EntityType.ENTITY_POOTER or
	target.Type == EntityType.ENTITY_ATTACKFLY or
	(target.Type == EntityType.ENTITY_SUCKER and (target.Variant < 2 or target.Variant == 3)) or -- Sucker, Spit, Ink
	target.Type == EntityType.ENTITY_EMBRYO or
	target.Type == EntityType.ENTITY_MOTER or
	target.Type == EntityType.ENTITY_SPIDER or
	target.Type == EntityType.ENTITY_BIGSPIDER or
	target.Type == EntityType.ENTITY_RING_OF_FLIES or
	target.Type == EntityType.ENTITY_DART_FLY or
	target.Type == EntityType.ENTITY_SWARM or
	target.Type == EntityType.ENTITY_HUSH_FLY or
	target.Type == EntityType.ENTITY_SMALL_LEECH or
	target.Type == EntityType.ENTITY_STRIDER or
	target.Type == EntityType.ENTITY_FLY_BOMB or
	target.Type == EntityType.ENTITY_SMALL_MAGGOT or
	target.Type == EntityType.ENTITY_ARMYFLY or
	target.Type == EntityType.ENTITY_SWARM_SPIDER or
	target.Type == EntityType.ENTITY_POOFER
	then
		return "small"
		
	elseif
	(target.Type == EntityType.ENTITY_BOOMFLY and target.Variant == 4) or -- Bone Fly
	(target.Type == EntityType.ENTITY_DEATHS_HEAD and target.Variant ~= 1) or -- for RedSkulls
	target.Type == EntityType.ENTITY_BONY or
	target.Type == EntityType.ENTITY_BLACK_BONY or
	target.Type == EntityType.ENTITY_MOMS_DEAD_HAND or
	target.Type == EntityType.ENTITY_NECRO or
	target.Type == EntityType.ENTITY_BIG_BONY or
	target.Type == EntityType.ENTITY_REVENANT or
	(target.Type == EntityType.ENTITY_NEEDLE and target.Variant == 1) or -- Pasty
	target.Type == EntityType.ENTITY_CLICKETY_CLACK or
	target.Type == EntityType.ENTITY_MAZE_ROAMER
	then
		return "bone"
		
	elseif
	target.Type == EntityType.ENTITY_DIP or
	target.Type == EntityType.ENTITY_SQUIRT or
	target.Type == EntityType.ENTITY_DINGA or
	target.Type == EntityType.ENTITY_DINGLE or
	target.Type == EntityType.ENTITY_CORN_MINE or
	target.Type == EntityType.ENTITY_BROWNIE or
	target.Type == EntityType.ENTITY_HENRY or
	target.Type == EntityType.ENTITY_DRIP or
	target.Type == EntityType.ENTITY_SPLURT or
	target.Type == EntityType.ENTITY_CLOGGY or
	target.Type == EntityType.ENTITY_DUMP
	then
		return "poop"
		
	elseif
	target.Type == EntityType.ENTITY_WIZOOB or
	target.Type == EntityType.ENTITY_THE_HAUNT or
	target.Type == EntityType.ENTITY_RED_GHOST or
	target.Type == EntityType.ENTITY_POLTY or
	(target.Type == EntityType.ENTITY_PREY and target.Variant == 1) or -- Mullighoul
	target.Type == EntityType.ENTITY_CANDLER or
	target.Type == EntityType.ENTITY_DUST
	then
		return "ghost"
		
	elseif
	(target.Type == EntityType.ENTITY_HOST and target.Variant == 3) or -- Hard Host
	target.Type == EntityType.ENTITY_BISHOP or
	target.Type == EntityType.ENTITY_ROCK_SPIDER or
	(target.Type == EntityType.ENTITY_DANNY and target.Variant == 1) or -- Coal Boy
	target.Type == EntityType.ENTITY_BLASTER or
	target.Type == EntityType.ENTITY_QUAKEY or
	target.Type == EntityType.ENTITY_HARDY
	then
		return "stone"
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.CorpseEaterInit, EntityType.ENTITY_GRUB)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.CorpseEaterUpdate, EntityType.ENTITY_GRUB)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, this.CorpseEaterCollision, EntityType.ENTITY_GRUB)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.CorpseEaterDeath, EntityType.ENTITY_GRUB)
end



return this