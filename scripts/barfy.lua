local this = {}
local game = Game()



local States = {
	NoSpit = 0,
	Spitting = 1
}



function this:barfyUpdate(entity)
	if entity.Variant == 850 then
		local sprite = entity:GetSprite()
		local data = entity:GetData()


		if sprite:IsEventTriggered("ShootStart") then
			data.state = States.Spitting
			SFXManager():Play(SoundEffect.SOUND_BOSS_SPIT_BLOB_BARF, 1, 0, false, 1, 0)
			
			-- Puke effect
			local effect = Isaac.Spawn(1000, EffectVariant.BLOOD_EXPLOSION, 3, entity.Position, Vector.Zero, entity)
			effect:GetSprite().Offset = Vector(0, -22)
			effect:GetSprite().Color = Color(0.5,1.2,0.75, 0.9, 0,0.3,0.1)
			effect.DepthOffset = entity.DepthOffset + 1
			
		elseif sprite:IsEventTriggered("ShootEnd") then
			data.state = States.NoSpit
		end
		

		-- Dumb bullshit for seperate left and right walking anims
		if sprite.FlipX == true then
			if sprite:IsPlaying("WalkHori") then
				sprite:ReplaceSpritesheet(0, "")
				sprite:ReplaceSpritesheet(2, "gfx/monsters/repentance/850.000_barfy.png")
				sprite:LoadGraphics()
			else
				sprite:ReplaceSpritesheet(2, "")
				sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/850.000_barfy.png")
				sprite:LoadGraphics()
			end
			
			sprite.FlipX = false
		else
			sprite:ReplaceSpritesheet(2, "")
			sprite:ReplaceSpritesheet(0, "gfx/monsters/repentance/850.000_barfy.png")
			sprite:LoadGraphics()
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



function this:vomitBulletInit(projectile)
	if projectile.SpawnerEntity ~= nil and projectile.SpawnerEntity.Type == 208 and projectile.SpawnerEntity.Variant == 850 then
		projectile:GetData().barfy = true
	end
end

function this:vomitBulletUpdate(projectile)
	if projectile:GetData().barfy == true and projectile:IsDead() then
		local puddle = Isaac.Spawn(1000, EffectVariant.CREEP_GREEN, 0, projectile.Position, Vector.Zero, projectile):ToEffect()
		puddle.Color = Color(1,1,1, 1, 0.4,0.1,0)
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.barfyUpdate, 208)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, this.vomitBulletInit, ProjectileVariant.PROJECTILE_PUKE)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, this.vomitBulletUpdate, ProjectileVariant.PROJECTILE_PUKE)
end



return this