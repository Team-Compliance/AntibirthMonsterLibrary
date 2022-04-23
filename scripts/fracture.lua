local this = {}
local game = Game()



local States = {
	NoSpit = 0,
	JumpSpit = 1,
	StandSpit = 2
}



function this:fractureUpdate(entity)
	if entity.Variant == 801 then
		local sprite = entity:GetSprite()
		local data = entity:GetData()
		local myRNG = RNG()
		local level = game:GetLevel()

		-- 50% chance to do spit attack after jumping
		if sprite:IsPlaying("Hop") and sprite:GetFrame() == 25 then
			myRNG:SetSeed(Random(), 801)
			
			if myRNG:RandomInt(2) == 1 then
				sprite:Play("Spit", true)
			end
			
			entity.Velocity = Vector(0,0)
			entity.TargetPosition = entity.Position
		end


		if sprite:IsEventTriggered("SpitBegin") then
			if sprite:IsPlaying("Hop") then
				data.state = States.JumpSpit
			else
				data.state = States.StandSpit
				
				-- Blood effect
				local effect = Isaac.Spawn(1000, EffectVariant.BLOOD_EXPLOSION, 3, entity.Position, Vector.Zero, entity):GetSprite()
				effect.Offset = Vector(0, -10)

				if level:GetStage() == LevelStage.STAGE1_1 or level:GetStage() == LevelStage.STAGE1_2 then
					if level:GetStageType() == StageType.STAGETYPE_REPENTANCE then
						effect.Color = Color(0.2, 0.8, 0.9, 1, 0.4,0.8,1.6)
					elseif level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
						effect.Color = Color(0.4, 1.2, 0.8, 1, 0.15,0.2,0.15)
					end
				end
			end
			
		elseif sprite:IsEventTriggered("SpitEnd") then
			data.state = States.NoSpit
		end


		-- Projectiles
		if data.state ~= nil then
			local params = ProjectileParams()
			params.FallingSpeedModifier = 2
			-- Different projectile colors for Downpour and Dross
			if level:GetStage() == LevelStage.STAGE1_1 or level:GetStage() == LevelStage.STAGE1_2 then
				if level:GetStageType() == StageType.STAGETYPE_REPENTANCE then
					params.Variant = ProjectileVariant.PROJECTILE_TEAR
				elseif level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
					params.Variant = ProjectileVariant.PROJECTILE_PUKE
				end
			end

			if data.state == States.JumpSpit then
				myRNG:SetSeed(Random(), 801)
				if myRNG:RandomInt(4) == 1 then
					entity:FireBossProjectiles(1, entity.TargetPosition, 1.5, params)
				end

			elseif data.state == States.StandSpit then
				entity:FireBossProjectiles(1, Vector(0,0), 1.25, params)
				entity:PlaySound(SoundEffect.SOUND_BOSS2_BUBBLES, 1, 0, false, 1)
			end
		
		else
			data.state = States.NoSpit
		end
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.fractureUpdate, 29)
end



return this