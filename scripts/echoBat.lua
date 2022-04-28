local this = {}
local game = Game()



local Settings = {
	AttackTime = {60, 120}, -- The amount of frames between each bat charge
	AttackRange = 280, -- Range players must be in to trigger the bat charging
	ChaseSpeed = 3.5, -- Velocity of bat following its target
	DirectionChangeTimes = {10, 30}, -- Amount of frames until the bat changes angle directions
	AngleOffset = {15, 35}, -- The angle offset the bat flies with
	ShotSpeed = 9.25 -- The speed of the echo rings
}



function getAngleOffset(direction)
	local multiplier = 1

	if (direction == "down") then
		multiplier = -1
	end

	return math.random(Settings.AngleOffset[1], Settings.AngleOffset[2]) * multiplier
end



function this:echoBatInit(entity)
	if entity.Variant == 2407 then
		local sprite = entity:GetSprite()
		local data = entity:GetData()

		
		data.cooldown = math.random(Settings.AttackTime[1], Settings.AttackTime[2])
		data.chargeDirection = Vector.Zero
		data.angleCountdown = math.random(Settings.DirectionChangeTimes[1], Settings.DirectionChangeTimes[2])
		data.angleOffset = math.random(Settings.AngleOffset[1], Settings.AngleOffset[2])
		data.angleDirection = "up"
	end
end



function this:echoBatUpdate(entity)
	if entity.Variant == 2407 then
		local sprite = entity:GetSprite()
		local data = entity:GetData()
		local target = entity:GetPlayerTarget()


		-- Movement
		data.vector = ((target.Position - entity.Position):Normalized() * Settings.ChaseSpeed):Rotated(data.angleOffset)
		if entity:HasEntityFlags(EntityFlag.FLAG_FEAR) or entity:HasEntityFlags(EntityFlag.FLAG_SHRINK) then
			data.vector = Vector(-data.vector.X, -data.vector.Y)
		end

		if entity:HasEntityFlags(EntityFlag.FLAG_CONFUSION) then
			entity.Pathfinder:MoveRandomly(false)
		else
			entity.Velocity = (entity.Velocity + (data.vector - entity.Velocity) * 0.25)
		end


		-- Change direction
		if data.angleCountdown <= 0 then
			if data.angleDirection == "up" then
				data.angleDirection = "down"
			else
				data.angleDirection = "up"
			end
			data.angleOffset = getAngleOffset(data.angleDirection)
			data.angleCountdown = math.random(Settings.DirectionChangeTimes[1], Settings.DirectionChangeTimes[2])
		end
		
		
		if not sprite:IsPlaying("Attack") and not sprite:IsPlaying("Idle") then
			sprite:Play("Idle", true)
		end


		if data.cooldown > 0 then
			data.cooldown = data.cooldown - 1
		end
		if data.angleCountdown > 0 then
			data.angleCountdown = data.angleCountdown - 1
		end


		-- Attacking
		if data.cooldown <= 0 and target.Position:Distance(entity.Position) <= Settings.AttackRange and not sprite:IsPlaying("Attack")
		and not (entity:HasEntityFlags(EntityFlag.FLAG_FEAR) or entity:HasEntityFlags(EntityFlag.FLAG_SHRINK) or entity:HasEntityFlags(EntityFlag.FLAG_CONFUSION)) then
			sprite:Play("Attack", true)
		end

		if sprite:IsEventTriggered("Sound") then
			entity:PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1.5, 0, false, 1.5)
		
		elseif sprite:IsEventTriggered("Shoot") then
			local params = ProjectileParams()
			params.Variant = 104
			params.FallingAccelModifier = -0.15

			entity:FireProjectiles(entity.Position, (target.Position - entity.Position):Normalized() * Settings.ShotSpeed, 0, params)
		end
		
		if sprite:GetFrame() == 56 then
			data.cooldown = math.random(Settings.AttackTime[1], Settings.AttackTime[2])
			sprite:Play("Idle", true)
		end
	end
end



-- Projectile
function this:echoRingInit(projectile)
	projectile:GetSprite():Play("Move", true)
	projectile:AddProjectileFlags(ProjectileFlags.GHOST)
	projectile.Mass = 0
end

function this:echoRingHit(target, damageAmount, damageFlags, damageSource, damageCountdownFrames)
	if damageSource.Type == EntityType.ENTITY_PROJECTILE and damageSource.Variant == 104 then
		if target.Type == EntityType.ENTITY_PLAYER then
			if not target:HasEntityFlags(EntityFlag.FLAG_SLOW) then
				target:AddSlowing(EntityRef(damageSource.Entity), 60, 0.8, Color(1,1,1, 1))
				target:SetColor(Color(1,1,1, 1, 0.15,0.15,0.15), 60, 1, false, false)
			end
		else
			--target:AddConfusion(EntityRef(damageSource.Entity), 45, false)
			target:AddSlowing(EntityRef(damageSource.Entity), 60, 0.8, Color(1,1,1, 1, 0.15,0.15,0.15))
		end

		return false
	end
end



function this:Init()
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.echoBatInit, 200)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.echoBatUpdate, 200)

	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, this.echoRingInit, 104)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, this.echoRingHit)
end



return this