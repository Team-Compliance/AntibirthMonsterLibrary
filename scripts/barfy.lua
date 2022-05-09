local this = {}
local game = Game()

local States = {
	NoSpit = 0,
	Spitting = 1
}



function this:barfyInit(entity)
	if entity.Variant == EntityVariant.BARFY then
		entity.SplatColor = Color(0.4,0.8,0.4, 1, 0,0.1,0)
		entity:GetData().isChamp = ""
			
		if entity:IsChampion() == true then
			entity:GetData().isChamp = "_champion"
		end
	end
end

function this:barfyUpdate(entity)
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
		
		
		-- Puke state
		if sprite:IsEventTriggered("ShootStart") then
			data.state = States.Spitting
			SFXManager():Play(SoundEffect.SOUND_BOSS_SPIT_BLOB_BARF, 1, 0, false, 1, 0)
			
			-- Puke effect
			local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 3, entity.Position, Vector.Zero, entity)
			effect:GetSprite().Offset = Vector(0, -22)
			effect:GetSprite().Color = Color(0.5,1.2,0.75, 0.9, 0,0.3,0.1)
			effect.DepthOffset = entity.DepthOffset + 1
			
		elseif sprite:IsEventTriggered("ShootEnd") then
			data.state = States.NoSpit
		end


		-- Projectiles
		if data.state ~= nil then
			if data.state == States.Spitting then
				local params = ProjectileParams()
				params.FallingSpeedModifier = 2
				params.Variant = ProjectileVariant.PROJECTILE_PUKE
				params.Color = Color(0.6,1,0.4, 1.1)

				entity:FireBossProjectiles(1, entity:GetPlayerTarget().Position, 1.2, params)
			end
		
		else
			data.state = States.NoSpit
		end
	end
end



-- Projectiles
function this:vomitBulletInit(projectile)
	if projectile.SpawnerEntity ~= nil and projectile.SpawnerEntity.Type == EntityType.ENTITY_FATTY and projectile.SpawnerEntity.Variant == EntityVariant.BARFY then
		projectile:GetData().barfy = true
	end
end

function this:vomitBulletUpdate(projectile)
	if projectile:GetData().barfy == true and projectile:IsDead() then
		local puddle = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CREEP_GREEN, 0, projectile.Position, Vector.Zero, projectile):ToEffect()
		puddle.Color = Color(1,1,1, 1, 0.4,0.1,0)
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.barfyInit, EntityType.ENTITY_FATTY)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.barfyUpdate, EntityType.ENTITY_FATTY)

	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, this.vomitBulletInit, ProjectileVariant.PROJECTILE_PUKE)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, this.vomitBulletUpdate, ProjectileVariant.PROJECTILE_PUKE)
end

return this