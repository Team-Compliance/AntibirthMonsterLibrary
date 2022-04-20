local this = {}

local Settings = {
	NumFollowerBats = 3, -- How many follower bats should spawn alongside the leader bat
	ActivationRange = 110, -- Range that players or monsters must be to trigger the bat
	AttackTime = {60, 120}, -- The amount of frames between each bat charge
	AttackRange = 80, -- Range players must be in to trigger the bat charging
	ChaseSpeed = 4, -- Velocity of bat following its target
	ChargeSpeed = 7, -- How fast the bat charges
	ChargeTime = 18,  -- How long the bat charges for
	DirectionChangeTimes = {10, 30}, -- Amount of frames until the bat changes angle directions
	AngleOffset = {15, 35}, -- The angle offset the bat flies with.
	InitialAlertTime = 30, -- The time it takes for the leader bat to alert the follower bats.
	AlertTime = {0, 20} -- The time in between each follower bat being alerted.
}

local States = {
	Hiding = 1,
	Spotted = 2,
	Chasing = 3,
	Charging = 4,
}

local nextAlertTime = Settings.InitialAlertTime
local batQueue = {}

math.randomseed(Isaac.GetTime())

function alarmBats()
	for _, bat in pairs(Isaac.FindByType(803, 0, 1, false, false)) do
		local data = bat:GetData().BlindBatData
		if (data ~= nil and data.State == States.Hiding) then
			table.insert(batQueue, bat)
		end
	end
	nextAlertTime = Settings.InitialAlertTime
end

function getAngleOffset(direction)

	local multiplier = 1

	if (direction == "down") then
		multiplier = -1
	end

	return math.random(Settings.AngleOffset[1], Settings.AngleOffset[2]) * multiplier

end

function awakenBats()

	for _, bat in pairs(Isaac.FindByType(803, 0 , 0, false, false)) do

		local batNpc = bat:ToNPC()
		local batSprite = bat:GetSprite()
		local batData = bat:GetData().BlindBatData

		if batData ~= nil and batData.State == States.Hiding then
			batData.State = States.Spotted
			batSprite:Play("Wake", true)
		end
	end

end

function this:blindBatInit(bat)

	local sprite = bat:GetSprite()
	
	bat:GetData().BlindBatData = {
		AttackCountdown = math.random(Settings.AttackTime[1], Settings.AttackTime[2]),
		State = States.Hiding,
		ChargeDirection = Vector.Zero,
		AngleCountdown = math.random(Settings.DirectionChangeTimes[1], Settings.DirectionChangeTimes[2]),
		AngleOffset = math.random(Settings.AlertTime[1], Settings.AlertTime[2]),
		AngleDirection = "up",
	}

	bat.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE

	if bat.SubType == 0 then
		sprite:Play("Idle", true)
		for i = 1, Settings.NumFollowerBats do
			Isaac.Spawn(803, 0, 1, bat.Position + RandomVector():Resized(math.random(1, 50)), bat.Velocity, bat)
		end
		
	elseif bat.SubType == 1 then
		bat:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end

end

function this:blindBatUpdate(bat)

	local sprite = bat:GetSprite()
	local batData = bat:GetData().BlindBatData
	local batPos = bat.Position
	local target = bat:GetPlayerTarget()
	

	if batData.State == States.Hiding then

		if bat.SubType == 0	 then

			for _, player in pairs(AntiMonsterLib:GetPlayers()) do
				if player.Position:Distance(batPos) <= Settings.ActivationRange then
					batData.State = States.Spotted
					sprite:Play("Wake", true)
					break
				end
			end

		elseif bat.SubType == 1 then
			sprite:Play("IdleInvisible", true)
		
			if #Isaac.FindByType(803, 0 , 0, undefined, false) <= 0 then
				bat:PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1, 0, false, 1.2)
				sprite:Play("FlyDown", true)
				batData.State = States.Spotted
			end
		end

	elseif batData.State == States.Spotted then
	
		if sprite:IsEventTriggered("Scream") then
			bat:PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1, 0, false, 1.2)
			alarmBats()
		elseif sprite:IsEventTriggered("Land") then
			bat.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
			sprite:Play("Fly", true)
			batData.State = States.Chasing
			sprite.Offset = Vector(0,-14)
		end

	elseif batData.State == States.Chasing then
		
		local targetVelocity = ((target.Position - batPos):Normalized() * Settings.ChaseSpeed):Rotated(batData.AngleOffset)
  
		if bat:HasEntityFlags(EntityFlag.FLAG_FEAR) then
			targetVelocity = Vector(-targetVelocity.X, -targetVelocity.Y)
		end
	
		if bat:HasEntityFlags(EntityFlag.FLAG_CONFUSION) then
			bat.Pathfinder:MoveRandomly(true)
		else
			bat.Velocity = targetVelocity
		end
	
		batData.AttackCountdown = batData.AttackCountdown - 1
		batData.AngleCountdown = batData.AngleCountdown - 1
	
		if batData.AttackCountdown <= 0 and target.Position:Distance(batPos) <= Settings.AttackRange then
			batData.AttackCountdown = Settings.ChargeTime
			batData.ChargeDirection = (target.Position - batPos):Normalized()
			batData.State = States.Charging
			sprite:Play("Dash", true)
			bat:PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1, 0, false, 1.2)
		end
	
		if batData.AngleCountdown <= 0 then
			if batData.AngleDirection == "up" then
				batData.AngleDirection = "down"
			else
				batData.AngleDirection = "up"
			end
			batData.AngleOffset = getAngleOffset(batData.AngleDirection)
			batData.AngleCountdown = math.random(Settings.DirectionChangeTimes[1], Settings.DirectionChangeTimes[2])
		end

	elseif batData.State == States.Charging then

		bat.Velocity = batData.ChargeDirection * Settings.ChargeSpeed
		batData.AttackCountdown = batData.AttackCountdown - 1;
  
		if batData.AttackCountdown <= 0 then
			batData.AttackCountdown = math.random(Settings.AttackTime[1], Settings.AttackTime[2])
			batData.State = States.Chasing
			sprite:Play("Fly", true)
		end
	end
end

function this:batRemoval(bat)
  
	for i = 1, #batQueue do
		if GetPtrHash(batQueue[i]) == GetPtrHash(bat) then
			table.remove(batQueue, i)
			break
		end
	end

end

function this:onUpdate()

	nextAlertTime = nextAlertTime - 1
  
	if nextAlertTime <= 0 then
		if #batQueue > 0 then

			local bat = batQueue[1]
			local batData = bat:GetData().BlindBatData

			if batData ~= nil and batData.State == States.Hiding then
				bat:ToNPC():PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1, 0, false, 1.2)
				bat:GetSprite():Play("FlyDown", true)
				batData.State = States.Spotted
			end

		end

		table.remove(batQueue, 1)
		nextAlertTime = math.random(Settings.AlertTime[1], Settings.AlertTime[2])

	end
  
	local offset = Game().ScreenShakeOffset
	local sfx = SFXManager()
  
	if (offset.X ~= 0 or offset.Y ~= 0)
	or (sfx:IsPlaying(SoundEffect.SOUND_BOSS1_EXPLOSIONS) or sfx:IsPlaying(SoundEffect.SOUND_EXPLOSION_STRONG)
	or sfx:IsPlaying(SoundEffect.SOUND_ROCKET_EXPLOSION) or sfx:IsPlaying(Isaac.GetSoundIdByName("Nightwatch Alert"))) then
		awakenBats()
	end
  
end

function this:Init()
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.blindBatInit, 803)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.blindBatUpdate, 803)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, this.batRemoval, 803)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_UPDATE, this.onUpdate)
end


return this
