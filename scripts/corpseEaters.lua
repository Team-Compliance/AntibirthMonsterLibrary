local mod = AntiMonsterLib
local game = Game()

local Settings = {
	GiveUpTime = 120,
	MaxHPMulti = 2,
	DetectionRange = 200,
	ChompDMG = 40,
	ChompCooldown = 10,
	BloodLength = 150,
	BonyCooldown = 25,
	BonyRange = 200,
	BonyShotSpeed = 11,
	ExtraProjectileCount = 3
}



-- For charmed and friendly Corpse Eaters
function CorpseEaterIsFriendly(entity, target)
	if target.Type == EntityType.ENTITY_GRUB and (target.Variant == EntityVariant.CORPSE_EATER or target.Variant == EntityVariant.CARRION_RIDER) then
		-- Non-friendly Corpse Eaters hurting charmed/baited ones
		if not (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and target:GetData().headIndex ~= entity.Index
		and (target:HasEntityFlags(EntityFlag.FLAG_CHARM) or target:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) or target:HasEntityFlags(EntityFlag.FLAG_BAITED)) then
			return true

		-- Charmed Corpse Eaters hurting non-friendly ones
		elseif (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) and not target:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and target:GetData().headIndex ~= entity.Index then
			return true
			
		else
			return false
		end

	elseif not (entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and target:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then
		return true
	end
end



function mod:CorpseEaterInit(entity)
	if entity.Variant == EntityVariant.CORPSE_EATER or entity.Variant == EntityVariant.CARRION_RIDER then
		local data = entity:GetData()
		local level = game:GetLevel()
		local stage = level:GetStage()

		-- Make them spawn more centered on the tile
		entity.Position = entity.Position + Vector(15,0)
		
		-- Set variables
		entity.CollisionDamage = 0
		data.MaxHP = entity.MaxHitPoints -- The maximum hp they can have from eating enemies
		entity.MaxHitPoints = entity.MaxHitPoints / 2
		data.GiveUpTime = 0
		data.ChompCooldown = Settings.ChompCooldown
		data.BloodLength = 0
		entity.ProjectileCooldown = Settings.BonyCooldown


		-- Set spritesheet
		data.altSkin = ""
		if (stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
			data.altSkin = "_gehenna"
		elseif (stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE then
			data.altSkin = "_corpse"
		end

		if data.altSkin ~= "" then
			local sprite = entity:GetSprite()
			sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/239.100_corpse_eater"		  .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(1, "gfx/monsters/repentance/239.100_corpse_eater_body"  .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(2, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
			sprite:ReplaceSpritesheet(3, "gfx/monsters/repentance/239.100_corpse_eater_rider" .. data.altSkin .. ".png")
			sprite:LoadGraphics()
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.CorpseEaterInit, EntityType.ENTITY_GRUB)

function mod:CorpseEaterUpdate(entity)
	if entity.Variant == EntityVariant.CORPSE_EATER or entity.Variant == EntityVariant.CARRION_RIDER then
		local data = entity:GetData()
		local target = entity.Target
		local sprite = entity:GetSprite()


		-- Get new target
		function getTarget()
			for i, enemy in pairs(Isaac.FindInRadius(entity.Position, Settings.DetectionRange, EntityPartition.ENEMY)) do
				if enemy:IsVulnerableEnemy() and entity.Pathfinder:HasPathToPos(enemy.Position, true) and inAMLblacklist("Corpse Eater", enemy.Type, enemy.Variant, enemy.SubType) == false then
					entity.Target = enemy
					data.GiveUpTime = Settings.GiveUpTime
				end
			end
		end

		if data.GiveUpTime > 0 then
			data.GiveUpTime = data.GiveUpTime - 1
		end
		if not target then
			getTarget()
		else
			if not target:IsVulnerableEnemy() or not entity.Pathfinder:HasPathToPos(target.Position, true) or target:IsDead() or data.GiveUpTime <= 0 then
				getTarget()
			end
		end

		
		-- Increased speed
		if entity.I1 == 1 then -- While charging
			entity.Velocity = entity.Velocity * 1.08
		else
			entity.Velocity = entity.Velocity * 1.03
		end
		
		-- Chomp cooldown
		if data.ChompCooldown > 0 then
			if entity.I1 == 1 then -- While charging
				data.ChompCooldown = data.ChompCooldown - 2
			else
				data.ChompCooldown = data.ChompCooldown - 1
			end
		end

		-- Make sure they don't get too tanky
		if entity.MaxHitPoints > data.MaxHP then
			entity.MaxHitPoints = data.MaxHP
		end
		
		
		-- Body segments
		-- Spawn the body if it doesn't already have one
		if not entity.Parent and not entity.Child then
			if entity.FrameCount <= 1 then
				Isaac.Spawn(EntityType.ENTITY_GRUB, EntityVariant.CORPSE_EATER, 1, entity.Position - Vector(30, 0), Vector.Zero, nil):GetData().headIndex = entity.Index
			
			elseif entity.FrameCount > 1 then
				entity:Remove()
			end

		elseif entity.Parent then
			-- Prevent them from getting longer than they should
			if entity.Child then
				entity.Child:Remove()
				
			-- Make the body always appear under the head
			elseif not entity.Child then
				entity.DepthOffset = entity.Parent.DepthOffset - 10
				
				if entity.Parent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
					entity:AddCharmed(EntityRef(entity.Parent), -1)
				end
			end
		end


		-- Creep + extra projectiles
		if data.BloodLength > 0 then
			-- Projectiles
			if sprite:IsEventTriggered("Chomp") and data.BloodLength < Settings.BloodLength - 10 then
				for i = 1, Settings.ExtraProjectileCount do
					local params = ProjectileParams()
					params.FallingAccelModifier = 0.15
					
					if math.random(0,5) == 3 then
						params.Variant = ProjectileVariant.PROJECTILE_BONE
					else
						params.Variant = ProjectileVariant.PROJECTILE_NORMAL
					end

					entity:FireBossProjectiles(1, entity.Position + Vector.FromAngle(entity.Velocity:GetAngleDegrees()), 0, params)
				end
			end
			
			-- Creep
			if entity:IsFrame(4, 0) then
				local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CREEP_RED, 0, entity.Position, Vector.Zero, entity):ToEffect()
				creep.Scale = 1.1
				creep:SetTimeout(45)
			end
			
			data.BloodLength = data.BloodLength - 1
		end


		-- Carrion Rider
		if entity.Variant == EntityVariant.CARRION_RIDER then
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
			
			
			if entity.Position:Distance(player.Position) <= Settings.BonyRange and entity.ProjectileCooldown <= 0
			and game:GetRoom():CheckLine(entity.Position, player.Position, 3, 0, false, false)
			and not (entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then
				-- Projectile
				local params = ProjectileParams()
				params.Variant = ProjectileVariant.PROJECTILE_BONE
				entity:FireProjectiles(entity.Position,(player.Position - entity.Position):Normalized() * Settings.BonyShotSpeed, 0, params)
				
				entity:PlaySound(SoundEffect.SOUND_SCAMPER, 1.25, 0, false, 1)
				entity.ProjectileCooldown = Settings.BonyCooldown
				
				-- Change head direction
				local angleDegrees = (player.Position - entity.Position):Normalized():GetAngleDegrees()
				local angle = 3

				if angleDegrees > -45 and angleDegrees < 45 then
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
					data.headFlip = false
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
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.CorpseEaterUpdate, EntityType.ENTITY_GRUB)

function mod:CorpseEaterCollision(entity, target, cum)
	if entity.Variant == EntityVariant.CORPSE_EATER or entity.Variant == EntityVariant.CARRION_RIDER then
		local data = entity:GetData()

		-- Players
		if target.Type == EntityType.ENTITY_PLAYER then
			target:TakeDamage(2, DamageFlag.DAMAGE_CRUSH, EntityRef(entity), 0)


		-- Enemies
		elseif entity.SubType == 0 and CorpseEaterIsFriendly(entity, target) == true and target:IsVulnerableEnemy() and data.ChompCooldown <= 0
		and not (target.Type == EntityType.ENTITY_VIS and target.Variant == 22) and not (entity:HasEntityFlags(EntityFlag.FLAG_FREEZE) or entity:HasEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE)) then
			target:TakeDamage(Settings.ChompDMG, DamageFlag.DAMAGE_CRUSH | DamageFlag.DAMAGE_IGNORE_ARMOR, EntityRef(entity), 0)
			data.ChompCooldown = Settings.ChompCooldown
			
			-- Effects
			local effect = GetEatenEffect(target.Type, target.Variant, target.SubType)
			if effect == false or effect == "dank" then -- No specified effect / dank
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 4, target.Position, Vector.Zero, nil):GetSprite().Color = target.SplatColor
				entity:PlaySound(SoundEffect.SOUND_MEATY_DEATHS, 0.75, 0, false, 1)
			
			elseif effect == "small" then
				entity:PlaySound(SoundEffect.SOUND_MEAT_IMPACTS, 1, 0, false, 1)
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 1, target.Position, Vector.Zero, nil)
				
			elseif effect == "bone" then
				entity:PlaySound(SoundEffect.SOUND_BONE_HEART, 0.75, 0, false, 1.1)
			
			elseif effect == "stone" then
				entity:PlaySound(SoundEffect.SOUND_STONE_IMPACT, 1, 0, false, 1)
				
			elseif effect == "poop" then
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOP_EXPLOSION, 0, target.Position, Vector.Zero, nil)
				entity:PlaySound(SoundEffect.SOUND_PLOP, 1, 0, false, 1)
			end
			

			-- If consumed
			if target:HasMortalDamage() then
				target:AddEntityFlags(EntityFlag.FLAG_EXTRA_GORE)
				entity.MaxHitPoints = entity.MaxHitPoints + math.ceil(target.MaxHitPoints / 2)
				entity.HitPoints = entity.HitPoints + math.ceil(target.MaxHitPoints / 2)
				
				-- No specified effect
				if effect == false then
					data.BloodLength = Settings.BloodLength

					Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 3, target.Position, Vector.Zero, nil)
					entity:PlaySound(SoundEffect.SOUND_SMB_LARGE_CHEWS_4, 1.5, 0, false, 1)
					
					-- Set skin to bloody one
					entity:GetSprite():ReplaceSpritesheet(0, "gfx/monsters/repentance/239.100_corpse_eater_2" .. data.altSkin .. ".png")
					entity:GetSprite():LoadGraphics()
					
					-- Projectiles
					for i = 1, math.random(0,3) + 6 + math.floor(target.MaxHitPoints / 10) do
						local params = ProjectileParams()
						if math.random(0,6) == 3 then
							params.Variant = ProjectileVariant.PROJECTILE_BONE
						else
							params.Variant = ProjectileVariant.PROJECTILE_NORMAL
						end
						entity:FireBossProjectiles(1, Vector.Zero, 2, params)
					end

				else
					entity:PlaySound(SoundEffect.SOUND_SMB_LARGE_CHEWS_4, 1, 0, false, 1)
					
					if effect ~= "small" then
						local params = ProjectileParams()
						if effect == "bone" then
							params.Variant = ProjectileVariant.PROJECTILE_BONE
							
						elseif effect == "stone" then
							params.Variant = ProjectileVariant.PROJECTILE_ROCK
							
						elseif effect == "poop" then
							params.Variant = ProjectileVariant.PROJECTILE_PUKE
							
						elseif effect == "dank" then
							local tarBulletColor = Color(0.5,0.5,0.5, 1, 0,0,0)
							tarBulletColor:SetColorize(1, 1, 1, 1)
							params.Color = tarBulletColor
							Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 3, target.Position, Vector.Zero, nil):GetSprite().Color = target.SplatColor
						end
						
						-- Projectiles
						entity:FireBossProjectiles(math.random(0,3) + 6, Vector.Zero, 2, params)
					end
				end
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.CorpseEaterCollision, EntityType.ENTITY_GRUB)

function mod:CorpseEaterDeath(entity)
	if entity.Variant == EntityVariant.CORPSE_EATER or entity.Variant == EntityVariant.CARRION_RIDER then
		-- Bony from Carrion Rider
		if entity.Variant == EntityVariant.CARRION_RIDER and entity.Parent == nil then
			local bony = Isaac.Spawn(EntityType.ENTITY_BONY, 0, 0, entity.Position, Vector.Zero, entity)
			
			if (game:GetLevel():GetStage() == LevelStage.STAGE4_1 or game:GetLevel():GetStage() == LevelStage.STAGE4_2) and game:GetLevel():GetStageType() == StageType.STAGETYPE_REPENTANCE then
				bony:GetSprite():ReplaceSpritesheet(0, "gfx/monsters/rebirth/monster_227_boney body_corpse.png")
				bony:GetSprite():ReplaceSpritesheet(1, "gfx/monsters/rebirth/monster_227_boney head_corpse.png")
				bony:GetSprite():LoadGraphics()
			end
		end

		-- Remove the maggots that are spawned on death
		for i, maggots in ipairs(Isaac.GetRoomEntities()) do
			if maggots.SpawnerType == EntityType.ENTITY_GRUB and (maggots.SpawnerVariant == EntityVariant.CORPSE_EATER or maggots.SpawnerVariant == EntityVariant.CARRION_RIDER)
			and maggots.Type == EntityType.ENTITY_MAGGOT or maggots.Type == EntityType.ENTITY_CHARGER or maggots.Type == EntityType.ENTITY_SPITTY then
				maggots:Remove()
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.CorpseEaterDeath, EntityType.ENTITY_GRUB)