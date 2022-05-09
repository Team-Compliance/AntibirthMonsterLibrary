local this = {}
local game = Game()

local Settings = {
	MoveSpeed = 1.25,
	ShotSpeed = 10,
	Cooldown = 18,
	Range = 240
}

local States = {
	Appear = 0,
	Moving = 1,
	Dead = 2
}



function this:stillbornInit(entity)
	if entity.Variant == AMLVariants.STILLBORN then
		local data = entity:GetData()
		local level = game:GetLevel()
		local stage = level:GetStage()
		local sprite = entity:GetSprite()
		local room = game:GetRoom()
		
		entity:ToNPC()
		entity.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		entity:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_HIDE_HP_BAR | EntityFlag.FLAG_NO_TARGET)

		-- Set Variables
		entity.MaxHitPoints = 0
		entity.ProjectileCooldown = Settings.Cooldown * 2 -- Longer cooldown on spawn
		data.state = States.Appear
		
		data.altSkin = ""
		if (stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE then
			if room:GetBackdropType() == BackdropType.CORPSE then
				data.altSkin = "_corpse"
				entity.SplatColor = Color(0.6,0.8,0.6, 1, 0,0.1,0)
			else
				data.altSkin = "_corpse2"
			end
		end
		
		
		-- Set sprites
		if data.altSkin ~= "" then
			for i = 0, sprite:GetLayerCount() do
				sprite:ReplaceSpritesheet(i, "gfx/monsters/repentance/802.000_stillborn" .. data.altSkin .. ".png")
			end
			sprite:LoadGraphics()
		end
	end
end



function this:stillbornUpdate(entity)
	if entity.Variant == AMLVariants.STILLBORN then
		local sprite = entity:GetSprite()
		local data = entity:GetData()
		local target = entity:GetPlayerTarget()
		local room = game:GetRoom()

		
		if data.state == States.Appear then
			data.state = States.Moving


		elseif data.state == States.Moving then
			if not sprite:IsPlaying("Idle") then
				sprite:Play("Idle", true)
			end

			entity.Velocity = (target.Position - entity.Position):Normalized() * Settings.MoveSpeed
			
			-- Shooting
			if entity.ProjectileCooldown > 0 then
				if not sprite:IsOverlayPlaying("IdleOverlay") then
					sprite:PlayOverlay("IdleOverlay", true)
				end
				
				entity.ProjectileCooldown = entity.ProjectileCooldown - 1
			
			else
				if entity.Position:Distance(target.Position) <= Settings.Range and room:CheckLine(entity.Position, target.Position, 3, 0, false, false) then
					if not sprite:IsOverlayPlaying("ShootOverlay") then
						sprite:PlayOverlay("ShootOverlay", true)
					end
				end
				
				if sprite:GetOverlayFrame() == 23 then
					entity:FireProjectiles(entity.Position, (target.Position - entity.Position):Normalized() * Settings.ShotSpeed, 0, ProjectileParams())
					entity:PlaySound(SoundEffect.SOUND_STONESHOOT, 1, 0, false, 1)
					entity.ProjectileCooldown = Settings.Cooldown
				end
			end

			-- Die on room clear
			if room:IsClear() then
				data.state = States.Dead
			end
		

		-- Death
		elseif data.state == States.Dead then
			entity.Velocity = Vector(0,0)
			
			if not sprite:IsPlaying("Death") then
				sprite:Play("Death", true)
				sprite:RemoveOverlay()
			end
			
			
			if sprite:IsEventTriggered("Snap") then
				entity:BloodExplode()
				
			elseif sprite:IsEventTriggered("Splat") then
				if room:GetGridCollisionAtPos(entity.Position) == GridCollisionClass.COLLISION_SOLID then
					room:GetGridEntityFromPos(entity.Position):Destroy(true)
					
				elseif room:GetGridCollisionAtPos(entity.Position) == GridCollisionClass.COLLISION_PIT then
					Isaac.Explode(entity.Position, entity, 100)
					entity:Kill()
					
				else
					SFXManager():Play(SoundEffect.SOUND_MEATY_DEATHS)
				end
				
			elseif sprite:IsEventTriggered("Explode") then
				Isaac.Explode(entity.Position, entity, 100)
				entity:Kill()
			end
		end
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.stillbornInit, EntityType.ENTITY_AML)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.stillbornUpdate, EntityType.ENTITY_AML)
end

return this