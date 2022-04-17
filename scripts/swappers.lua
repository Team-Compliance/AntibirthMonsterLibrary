local this = {}
local game = Game()



function swapperShoot(source, targetpos)
	-- Set laser start and end position
	local laser_source_pos = source.Position
	local laser_ent_pair = {laser = EntityLaser.ShootAngle(2, laser_source_pos, ((targetpos - laser_source_pos):GetAngleDegrees()), 3, Vector(0, source.SpriteScale.Y * -48), source), source}
	local _, endPos = game:GetRoom():CheckLine(laser_source_pos, targetpos, 3)
	laser_ent_pair.laser:SetMaxDistance(laser_source_pos:Distance(endPos))

	-- Extra parameters
	laser_ent_pair.laser.Mass = 0
	laser_ent_pair.laser.DepthOffset = 200
	laser_ent_pair.laser.DisableFollowParent = true
	laser_ent_pair.laser.OneHit = true
	
	if source.SubType == 1 then -- Gehenna color
		laser_ent_pair.laser:SetColor(Color(1,1,1, 1, 0.8,0.1,0.3), 0, 1, false, false)
	else
		laser_ent_pair.laser:SetColor(Color(1,1,1, 1, 0.2,0.1,0.8), 0, 1, false, false)
	end
end



function this:swapperHit(target, damageAmount, damageFlags, damageSource, damageCountdownFrames)
	if damageSource.Type == EntityType.ENTITY_BABY and damageSource.Variant == 835 and damageSource.Entity:GetData().canTP == true then
		-- Get positions for teleporting
		local swapToPos = damageSource.Entity.Position
		local swapFromPos = target.Position
		
		-- Make sure they don't teleport the player on top of rocks or pits when they can't fly
		local room = game:GetRoom()
		if target:ToPlayer().CanFly == false and (room:GetGridCollisionAtPos(swapToPos) == GridCollisionClass.COLLISION_PIT or room:GetGridCollisionAtPos(swapToPos) == GridCollisionClass.COLLISION_SOLID) then
			swapToPos = room:FindFreeTilePosition(swapToPos, 52)
		end


		-- Visuals + sound
		if not (damageSource.Entity:HasEntityFlags(EntityFlag.FLAG_CHARM) or damageSource.Entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)) then
			target:ToPlayer():AnimateTeleport(false)
			target:GetSprite():SetFrame(12)
		
			damageSource.Entity:GetSprite():Play("TeleportDown", true)
			SFXManager():Play(SoundEffect.SOUND_HELL_PORTAL2, 1, 0, false, 1, 0)


			target.Position = swapToPos
			damageSource.Entity.Position = swapFromPos
		end
		damageSource.Entity:GetData().canTP = false

		return false
	end
end



function this:swapperUpdate(entity)
	if entity.Variant == 835 then
		local sprite = entity:GetSprite()
		local target = entity:GetPlayerTarget()
		local data = entity:GetData()
		local level = game:GetLevel()
		local stage = level:GetStage()

		
		if entity:GetChampionColorIdx() == ChampionColor.GREEN or entity:GetChampionColorIdx() == ChampionColor.RAINBOW or entity:GetChampionColorIdx() == ChampionColor.BROWN then
			entity:MakeChampion(1, -1, true)
		end

		if (stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
			entity:Morph(entity.Type, entity.Variant, 1, entity:GetChampionColorIdx())
		end

		
		if sprite:IsEventTriggered("GetPos") then
			data.pos = target.Position
			
		elseif sprite:IsEventTriggered("Laser") then
			data.canTP = true
			swapperShoot(entity,data.pos)
			
		elseif sprite:IsEventTriggered("NoTp") then
			data.canTP = false
		end
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.swapperUpdate, EntityType.ENTITY_BABY)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, this.swapperHit, EntityType.ENTITY_PLAYER)
end



return this