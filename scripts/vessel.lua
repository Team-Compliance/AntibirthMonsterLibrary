local this = {}

local Settings = {
  MaxMaggots = 12,
  GridCountdown = 30,
  MoveSpeed = 1.5,
  StepMaggotSpawnChance = 0.05,
  AttackTime = {30*4, 30*5},
  MaggotSpeed = 0.2,
  MaggotCounterChance = 0.7,
  MaggotsToShoot = 3,
  GrowlCountdown = 60
}

local States = {
  Moving = 1,
  Attacking = 2,
}


function this:vesselInit(vessel)
    
    vessel:GetData().VesselData = {
        State = States.Moving,
        Maggots = 0,
        GridCountdown = 0,
        AttackCountdown = math.random(Settings.AttackTime[1], Settings.AttackTime[2]),
        CreepSpawned = 0,
        CreepsToSpawn = 0,
        CreepAngles = {},
        GrowlCountdown = Settings.GrowlCountdown
    }

end

function this:vesselUpdate(vessel)

    local vesselData = vessel:GetData().VesselData
    local vesselSprite = vessel:GetSprite()
    local pathfinder = vessel.Pathfinder
    local target = vessel:GetPlayerTarget()


    if vesselData.State == States.Moving then

       vessel:AnimWalkFrame("WalkHori", "WalkVert", 1)

       vesselData.GrowlCountdown = vesselData.GrowlCountdown - 1

       if vesselData.GrowlCountdown <= 0 then
            vessel:PlaySound(SoundEffect.SOUND_MONSTER_ROAR_1, 1, 0, false, 1)
            vesselData.GrowlCountdown = Settings.GrowlCountdown
       end

        if vessel:HasEntityFlags(EntityFlag.FLAG_CONFUSION | EntityFlag.FLAG_FEAR) then
            pathfinder:MoveRandomly(false)
        elseif vessel:CollidesWithGrid() or vesselData.GridCountdown > 0 then
            if vesselData.GridCountdown <= 0 then
                vesselData.GridCountdown = 30
            end
            pathfinder:FindGridPath(target.Position, Settings.MoveSpeed/6, 1, false)
        else
            vessel.Velocity = (target.Position -  vessel.Position):Normalized() * Settings.MoveSpeed
        end

        if vesselSprite:IsEventTriggered("Step") and math.random() <= Settings.StepMaggotSpawnChance and vesselData.Maggots < Settings.MaxMaggots then
            local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, Vector(0, 0), vessel)
            maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
            vesselData.Maggots = vesselData.Maggots + 1
        end

        if not vessel:HasEntityFlags(EntityFlag.FLAG_CONFUSION | EntityFlag.FLAG_FEAR) then
            vesselData.AttackCountdown = vesselData.AttackCountdown - 1
            vesselData.GridCountdown = vesselData.GridCountdown - 1
        end

        if vesselData.AttackCountdown <= 0 then
            vessel:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
            vessel:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            vessel:PlaySound(SoundEffect.SOUND_ANGRY_GURGLE, 1, 0, false, 1)
            if vesselSprite:GetAnimation() == "WalkHori" then
                vesselSprite:Play("AttackHori", true)
            else
                vesselSprite:Play("AttackVert", true)
            end
            vesselData.State = States.Attacking
        end
    
    elseif vesselData.State == States.Attacking then

        vessel.Velocity = Vector(0, 0)

        if vesselSprite:IsEventTriggered("Shoot") then
            
            vesselData.CreepSpawned = 0
            vesselData.CreepsToSpawn = 4
            vesselData.CreepAngles = {}

            for i = 1, vesselData.CreepsToSpawn do
                table.insert(vesselData.CreepAngles, math.random(0, 360))
            end

            Game():ButterBeanFart(vessel.Position, 100, vessel, true, false)
            vessel:PlaySound(SoundEffect.SOUND_FART, 1, 0, false, 1)

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

        if vesselSprite:WasEventTriggered("Shoot") and vesselData.CreepSpawned < vesselData.CreepsToSpawn then

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
            vessel:ClearEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
            vessel:ClearEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            vesselData.State = States.Moving
        end


    end

end

function this:vesselDamage(vessel, damageAmount, damageFlags, damageSource, damageCountdownFrames)

    if vessel:HasEntityFlags(EntityFlag.FLAG_FEAR | EntityFlag.FLAG_CONFUSION) then return end

    local vesselData = vessel:GetData().VesselData

    local targetPos

    if damageSource.Entity.Spawner == nil then
        targetPos = damageSource.Entity.Position
    else
        targetPos = damageSource.Entity.Spawner.Position
    end
    
    local targetVelocity = (targetPos - vessel.Position):Normalized() * 7

    if vesselData.Maggots >= Settings.MaxMaggots or math.random() < Settings.MaggotCounterChance then return end

    vesselData.Maggots = vesselData.Maggots + 1

    local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, targetVelocity, vessel):ToNPC()
    maggot.V1 = Vector(-8, 10)
    maggot.I1 = 1
    maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    maggot.State = NpcState.STATE_SPECIAL

end

function this:maggotDeath(maggot)

    local spawner = maggot.SpawnerEntity

    if spawner and spawner.Type == 858 then
        spawner:GetData().VesselData.Maggots = spawner:GetData().VesselData.Maggots - 1
    end

end

function this:vesselDeath(vessel)

    for i = 1, 10 do
        local maggot = Isaac.Spawn(EntityType.ENTITY_SMALL_MAGGOT, 0, 0, vessel.Position, Vector.FromAngle(math.random(0, 360)):Normalized() * math.random(1, 2), vessel):ToNPC()
        maggot.V1 = Vector(-12, 10)
        maggot.I1 = 1
        maggot:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        maggot.State = NpcState.STATE_SPECIAL
    end

end

function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.vesselInit, 858)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.vesselUpdate, 858)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, this.vesselDamage, 858)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.maggotDeath, EntityType.ENTITY_SMALL_MAGGOT)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.vesselDeath, 858)
end

return this