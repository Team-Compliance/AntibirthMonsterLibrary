local this = {}
local game = Game()



local DumplingVariants = {
    DUMPLING = 0,
    SKINLING = 1,
    SCAB = 2
}



--[[
    Dumpling/Skinling/Scab fart helper function
--]]
local function fart(npc)
	if npc.Variant == DumplingVariants.DUMPLING then -- Dumpling
		game:ButterBeanFart(npc.Position, 85, npc, true)
		
	elseif npc.Variant == DumplingVariants.SKINLING then -- Skinling
		game:ButterBeanFart(npc.Position, 85, npc, false) -- fart but don't show
		game:Fart(npc.Position, 0, npc)
		
		if game:GetNearestPlayer(npc.Position).Position:Distance(npc.Position) < 80 then
			game:GetNearestPlayer(npc.Position):TakeDamage(1, DamageFlag.DAMAGE_POISON_BURN, EntityRef(npc), 0)
		end
		
	elseif npc.Variant == DumplingVariants.SCAB then -- Scab
		game:ButterBeanFart(npc.Position, 85, npc, false) -- fart but don't show
		game:Fart(npc.Position, 0, npc, 1, 1) -- red fart

		params = ProjectileParams()
		params.CircleAngle = 0
		npc:FireProjectiles(npc.Position, Vector(10, 6), 9, params)
	end
end

--[[
    Helper function to apply velocity to and flip an NPC's sprite
--]]
local function add_velocity_and_flip(npc, velocity)
    npc:AddVelocity(velocity)
    npc:GetSprite().FlipX = (velocity.X < 0)
end



function this:NPCUpdate(npc)
    local sprite = npc:GetSprite() -- get entity sprite
    local npc_flags = npc:GetEntityFlags()
    local player_position = game:GetNearestPlayer(npc.Position).Position
    local player_angle = (player_position - npc.Position):GetAngleDegrees()
	
	npc.Visible = true -- fixes some of them becoming invisible
	
	if npc.State == NpcState.STATE_IDLE then -- if idling
		sprite:Play("Idle")
		if player_position:Distance(npc.Position) < 100 then -- if player is close
			npc.State = NpcState.STATE_ATTACK
			sprite:Play("Fart")
			
		elseif (npc_flags & EntityFlag.FLAG_FEAR == EntityFlag.FLAG_FEAR) and math.random(16) == 1 then -- move feared 
			npc.State = NpcState.STATE_MOVE
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + 180) * Vector(math.random(3)+3, math.random(3)+3))
			sprite:Play("Move")
			
		elseif (npc.Variant == DumplingVariants.DUMPLING or npc.Variant == DumplingVariants.SKINLING) and math.random(20) == 1 and not feared then -- move random 
			npc.State = NpcState.STATE_MOVE
			add_velocity_and_flip(npc, Vector.FromAngle(player_angle + (math.random(180)-90)) * Vector(math.random(3)+4, math.random(3)+4))
			sprite:Play("Move")
			
		elseif npc.Variant == DumplingVariants.SCAB and math.random(12) == 1 and not (npc_flags & EntityFlag.FLAG_FEAR == EntityFlag.FLAG_FEAR) then -- move towards player
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
		if npc.Variant == DumplingVariants.SKINLING then
			npc.SplatColor = Color(0.6,0.8,0.6, 1, 0,0.1,0)
		end
	end 
end



function this:NPCDamage(entity, amount, dmg_flags)
    local npc = entity:ToNPC()
    
    npc.State = NpcState.STATE_ATTACK2
    npc:GetSprite():Play("Fart")
end



function this:NPCDeath(entity)
    local npc = entity:ToNPC()
    fart(npc)
end



function this:Init()
	AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.NPCUpdate, 800)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, this.NPCDamage, 800)
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, this.NPCDeath, 800)
end



return this