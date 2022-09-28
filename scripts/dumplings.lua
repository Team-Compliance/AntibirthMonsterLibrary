local mod = AntiMonsterLib
local game = Game()



-- Fart helper function
local function fart(npc)
	local visible = false

	-- Dumpling
	if npc.Variant == EntityVariant.DUMPLING then
		visible = true

	-- Skinling
	elseif npc.Variant == EntityVariant.SKINLING then
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART, 0, npc.Position, Vector.Zero, npc) -- green fart

		local partition = EntityPartition.PLAYER
		if npc:HasEntityFlags(EntityFlag.FLAG_CHARM) then
			partition = 40
		elseif npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			partition = EntityPartition.ENEMY
		end

		for i, e in pairs(Isaac.FindInRadius(npc.Position, 70, partition)) do
			if e.Index ~= npc.Index and not e:IsInvincible() then
				local dmg = 5
				local multiplier = 1

				if npc:IsChampion() then
					multiplier = 2
				end
				if e.Type == EntityType.ENTITY_PLAYER then
					dmg = 1
				else
					e:AddPoison(EntityRef(npc), 64, 2)
				end

				e:TakeDamage(dmg * multiplier, DamageFlag.DAMAGE_POISON_BURN, EntityRef(npc), 0)
			end
		end

	-- Scab
	elseif npc.Variant == EntityVariant.SCAB then
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART, 1, npc.Position, Vector.Zero, npc) -- red fart

		local params = ProjectileParams()
		params.CircleAngle = 0
		npc:FireProjectiles(npc.Position, Vector(10, 6), 9, params)
	end

	game:ButterBeanFart(npc.Position, 85, npc, visible, false)
end

-- Helper function to apply velocity to and flip a Dumpling's sprite
local function add_velocity_and_flip(npc, velocity)
    npc:AddVelocity(velocity)
    npc:GetSprite().FlipX = (velocity.X < 0)
end



function mod:dumplingUpdate(npc)
    local sprite = npc:GetSprite()
    local player_position = game:GetNearestPlayer(npc.Position).Position
    local player_angle = (player_position - npc.Position):GetAngleDegrees()
    local feared = npc:HasEntityFlags(EntityFlag.FLAG_FEAR)


	npc.Visible = true -- fixes some of them becoming invisible

	if npc.State == NpcState.STATE_IDLE then -- if idling
		sprite:Play("Idle")
		if player_position:Distance(npc.Position) < 100 then -- if player is close
			npc.State = NpcState.STATE_ATTACK
			sprite:Play("Fart")

		elseif feared and math.random(16) == 1 then -- move feared 
			npc.State = NpcState.STATE_MOVE
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + 180) * Vector(math.random(3)+3, math.random(3)+3))
			sprite:Play("Move")

		elseif (npc.Variant == EntityVariant.DUMPLING or npc.Variant == EntityVariant.SKINLING) and math.random(20) == 1 and not feared then -- move random 
			npc.State = NpcState.STATE_MOVE
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + (math.random(180)-90)) * Vector(math.random(3)+4, math.random(3)+4))
			sprite:Play("Move")

		elseif npc.Variant == EntityVariant.SCAB and math.random(12) == 1 and not feared then -- move towards player
			npc.State = NpcState.STATE_MOVE
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle) * Vector(math.random(3)+3, math.random(3)+3))
			sprite:Play("Move")
		end


	elseif npc.State == NpcState.STATE_MOVE then -- if moving
		if sprite:IsFinished("Move") then
			npc.State = NpcState.STATE_IDLE
		end


	elseif npc.State == NpcState.STATE_ATTACK then -- if farting
		if sprite:IsEventTriggered("Fart") then
			fart(npc)
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + 180) * Vector(math.random(3)+18, math.random(3)+18))

		elseif sprite:IsFinished("Fart") then
			npc.State = NpcState.STATE_IDLE
		end


	elseif npc.State == NpcState.STATE_ATTACK2 then -- if farting from taken damage
		if sprite:IsEventTriggered("Fart") then
			fart(npc)
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + (math.random(90)-45) + 180) * Vector(math.random(3)+18, math.random(3)+18))

		elseif sprite:IsFinished("Fart") then
			npc.State = NpcState.STATE_IDLE
		end


	elseif npc.State == NpcState.STATE_INIT then -- if newly spawned
		npc.State = NpcState.STATE_IDLE

		if npc.Variant == EntityVariant.SKINLING then
			npc.SplatColor = Color(0.6,0.8,0.6, 1, 0,0.1,0)
		end
	end 
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.dumplingUpdate, EntityType.ENTITY_DUMPLING)

-- Fart on damage
function mod:dumplingDMG(entity, amount, dmg_flags)
    entity:ToNPC().State = NpcState.STATE_ATTACK2
    entity:GetSprite():Play("Fart")
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.dumplingDMG, EntityType.ENTITY_DUMPLING)

-- Fart on death
function mod:dumplingDeath(entity)
    fart(entity)
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.dumplingDeath, EntityType.ENTITY_DUMPLING)