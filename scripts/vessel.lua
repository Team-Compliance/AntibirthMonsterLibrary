local mod = AntiMonsterLib
local game = Game()

local Settings = {
	MaxMaggots = 12,
	MoveSpeed = 1.5,
	StepMaggotSpawnChance = 0.05,
	AttackTime = {30 * 4, 30 * 5},
	MaggotSpeed = 0.2,
	MaggotCounterChance = 0.7,
	MaggotsToShoot = 3,
	GrowlCountdown = 60,
	CreepsToSpawn = 4,
	MaggotsOnDeath = 8
}

local States = {
  Moving = 1,
  Attacking = 2
}



function mod:vesselInit(vessel)
	vessel.SplatColor = Color(0.4,0.8,0.4, 1, 0,0.1,0)
	
    vessel:GetData().VesselData = {
        State = States.Moving,
        Maggots = 0,
        AttackCountdown = math.random(Settings.AttackTime[1], Settings.AttackTime[2]),
        CreepSpawned = 0,
        CreepsToSpawn = 0,
        CreepAngles = {},
        GrowlCountdown = Settings.GrowlCountdown
    }
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.vesselInit, EntityType.ENTITY_VESSEL)

function mod:vesselUpdate(vessel)
    local vesselData = vessel:GetData().VesselData
    local vesselSprite = vessel:GetSprite()
    local pathfinder = vessel.Pathfinder
    local target = vessel:GetPlayerTarget()


    if vesselData.State == States.Moving then
		vessel:AnimWalkFrame("WalkHori", "WalkVert", 1)

		-- Movement
		local speed = Settings.MoveSpeed
		if vessel:HasEntityFlags(EntityFlag.FLAG_FEAR) or vessel:HasEntityFlags(EntityFlag.FLAG_SHRINK) then
			speed = -speed
		end

		if vessel:HasEntityFlags(EntityFlag.FLAG_CONFUSION) then
			vessel.Pathfinder:MoveRandomly(false)

		else
			if vessel.Pathfinder:HasPathToPos(target.Position) then
				if game:GetRoom():CheckLine(vessel.Position, target.Position, 0, 0, false, false) then
					vessel.Velocity = (vessel.Velocity + ((target.Position - vessel.Position):Normalized() * speed - vessel.Velocity) * 0.25)
				
				else
					vessel.Pathfinder:FindGridPath(target.Position, speed / 6, 500, false)
				end
			
			else
				vessel.Velocity = (vessel.Velocity + (Vector.Zero - vessel.Velocity) * 0.25)
			end
		end
		
		
		-- Sound
		vesselData.GrowlCountdown = vesselData.GrowlCountdown - 1

		if vesselData.GrowlCountdown <= 0 then
			vessel:PlaySound(SoundEffect.SOUND_MONSTER_ROAR_1, 1, 0, false, 1)
			vesselData.GrowlCountdown = Settings.GrowlCountdown
		end
		

		-- Spawn maggot
        if vesselSprite:IsEventTriggered("Step") and math.random() <= Settings.StepMaggotSpawnChance and vesselData.Maggots < Settings.MaxMaggots then
            local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, Vector(0, 0), vessel)
            maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
            vesselData.Maggots = vesselData.Maggots + 1
        end


		-- Attack
        if not vessel:HasEntityFlags(EntityFlag.FLAG_CONFUSION | EntityFlag.FLAG_FEAR) then
            vesselData.AttackCountdown = vesselData.AttackCountdown - 1
        end

        if vesselData.AttackCountdown <= 0 then
            if vesselSprite:GetAnimation() == "WalkHori" then
                vesselSprite:Play("AttackHori", true)
            else
                vesselSprite:Play("AttackVert", true)
            end

			vessel:PlaySound(SoundEffect.SOUND_ANGRY_GURGLE, 1, 0, false, 1)
            vesselData.State = States.Attacking
		end


	-- Attacking
    elseif vesselData.State == States.Attacking then
        vessel.Velocity = Vector.Zero

        if vesselSprite:IsEventTriggered("Shoot") then
            vesselData.CreepSpawned = 0
            vesselData.CreepAngles = {}
			
			game:ButterBeanFart(vessel.Position, 100, vessel, false, false) -- fart but don't show
			game:Fart(vessel.Position, 0, vessel)
            vessel:PlaySound(SoundEffect.SOUND_FART, 1, 0, false, 1)

			-- Get creep angles
            for i = 1, Settings.CreepsToSpawn do
                table.insert(vesselData.CreepAngles, math.random(0, 360))
            end

			-- Spawn maggots
            for i = 1, Settings.MaggotsToShoot do
                if vesselData.Maggots < Settings.MaxMaggots then
                    local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, Vector.FromAngle(math.random(0, 360)):Normalized() * (math.random(2, 3)), vessel):ToNPC()
                    maggot.V1 = Vector(-10, 10)
                    maggot.I1 = 1
                    maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
                    maggot.State = NpcState.STATE_SPECIAL
                    vesselData.Maggots = vesselData.Maggots + 1
                else
                    break
                end
            end
        end

		-- Spawn creep
        if vesselSprite:WasEventTriggered("Shoot") and vesselData.CreepSpawned < Settings.CreepsToSpawn then
            vesselData.CreepSpawned = vesselData.CreepSpawned + 1

            for _, angle in pairs(vesselData.CreepAngles) do
                local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CREEP_GREEN, 0, (vessel.Position) + Vector.FromAngle(angle):Normalized() * (vesselData.CreepSpawned * 25), Vector(0, 0), vessel)
                if vesselData.CreepSpawned == 1 then
                    creep:GetSprite().Scale = Vector(2, 2)
                else
                    creep:GetSprite().Scale = Vector(1, 1)
                end       
            end
 
        end

        if vesselSprite:IsFinished(vesselSprite:GetAnimation()) then
            vesselData.AttackCountdown = math.random(Settings.AttackTime[1], Settings.AttackTime[2])
            vesselData.State = States.Moving
        end
    end
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.vesselUpdate, EntityType.ENTITY_VESSEL)

-- Spawn maggots when taking damage
function mod:vesselDamage(vessel, damageAmount, damageFlags, damageSource, damageCountdownFrames)
	local vesselData = vessel:GetData().VesselData
	local targetPos = damageSource.Entity


	if vesselData.Maggots >= Settings.MaxMaggots or math.random() < Settings.MaggotCounterChance then return end

    if damageSource.Entity.Spawner == nil then
        targetPos = damageSource.Entity.Position
    else
        targetPos = damageSource.Entity.Spawner.Position
    end

    local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, (targetPos - vessel.Position):Normalized() * 7, vessel):ToNPC()
    maggot.V1 = Vector(-8, 10)
    maggot.I1 = 1
    maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    maggot.State = NpcState.STATE_SPECIAL
	vesselData.Maggots = vesselData.Maggots + 1
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.vesselDamage, EntityType.ENTITY_VESSEL)

-- Spawn maggots on death
function mod:vesselDeath(vessel)
    for i = 1, Settings.MaggotsOnDeath do
        local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, Vector.FromAngle(math.random(0, 360)):Normalized() * math.random(1, 2), vessel):ToNPC()
        maggot.V1 = Vector(-12, 10)
        maggot.I1 = 1
        maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        maggot.State = NpcState.STATE_SPECIAL
    end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.vesselDeath, EntityType.ENTITY_VESSEL)



function mod:maggotDeath(maggot)
	if maggot.SpawnerEntity then
		local spawner = maggot.SpawnerEntity

		if spawner.Type == EntityType.ENTITY_VESSEL and spawner:GetData().VesselData.Maggots then
			spawner:GetData().VesselData.Maggots = spawner:GetData().VesselData.Maggots - 1
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.maggotDeath, EntityType.ENTITY_SMALL_MAGGOT)