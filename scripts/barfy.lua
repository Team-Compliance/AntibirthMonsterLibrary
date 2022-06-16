local mod = AntiMonsterLib
local game = Game()



function mod:barfyInit(entity)
	if entity.Variant == EntityVariant.BARFY then
		local data = entity:GetData()

		entity.SplatColor = Color(0.4,0.8,0.4, 1, 0,0.1,0)
		data.attacking = false

		data.isChamp = ""
		if entity:IsChampion() == true then
			data.isChamp = "_champion"
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.barfyInit, EntityType.ENTITY_FATTY)

function mod:barfyUpdate(entity)
	if entity.Variant == EntityVariant.BARFY then
		local sprite = entity:GetSprite()
		local data = entity:GetData()


		if sprite.FlipX == true then
			if sprite:IsPlaying("WalkHori") then
				sprite:ReplaceSpritesheet(0, "")
				sprite:ReplaceSpritesheet(2, "gfx/monsters/repentance/850.000_barfy" .. data.isChamp .. ".png")
				sprite:LoadGraphics()
			else -- Stops the body sprite from flickering if going to the attack state
				sprite:ReplaceSpritesheet(2, "")
				sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/850.000_barfy" .. data.isChamp .. ".png")
				sprite:LoadGraphics()
			end
			sprite.FlipX = false

		else
			sprite:ReplaceSpritesheet(2, "")
			sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/850.000_barfy" .. data.isChamp .. ".png")
			sprite:LoadGraphics()
		end


		-- Attacking
		if sprite:IsEventTriggered("ShootStart") then
			data.attacking = true
			SFXManager():Play(SoundEffect.SOUND_BOSS_SPIT_BLOB_BARF, 1, 0, false, 1, 0)
			
			-- Puke effect
			local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 3, entity.Position, Vector.Zero, entity)
			effect:GetSprite().Offset = Vector(0, -22)
			effect:GetSprite().Color = Color(0.5,1.2,0.75, 0.9, 0,0.3,0.1)
			effect.DepthOffset = entity.DepthOffset + 1
			
		elseif sprite:IsEventTriggered("ShootEnd") then
			data.attacking = false
		end


		-- Projectiles
		if data.attacking == true then
			local params = ProjectileParams()
			params.FallingSpeedModifier = 2
			params.Variant = ProjectileVariant.PROJECTILE_PUKE
			params.Color = Color(0.6,1,0.4, 1.1)

			entity:FireBossProjectiles(1, entity:GetPlayerTarget().Position, 1.2, params)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.barfyUpdate, EntityType.ENTITY_FATTY)



-- Projectiles
function mod:vomitBulletInit(projectile)
	if projectile.SpawnerEntity ~= nil and projectile.SpawnerEntity.Type == EntityType.ENTITY_FATTY and projectile.SpawnerEntity.Variant == EntityVariant.BARFY then
		projectile:GetData().barfy = true
	end
end
mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, mod.vomitBulletInit, ProjectileVariant.PROJECTILE_PUKE)

function mod:vomitBulletUpdate(projectile)
	if projectile:GetData().barfy == true and projectile:IsDead() then
		local puddle = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CREEP_GREEN, 0, projectile.Position, Vector.Zero, projectile):ToEffect()
		puddle.Color = Color(1,1,1, 1, 0.4,0.1,0)
	end
end
mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, mod.vomitBulletUpdate, ProjectileVariant.PROJECTILE_PUKE)