local this = {}
local game = Game()

local Settings = {
	MoveSpeed = 1,
	AngrySpeed = 2.25,
	Range = 100,
	SoundTimer = {180, 210}
}

local States = {
	Appear = 0,
	Moving = 1,
	Scream = 2,
	Angry = 3
}



function this:screamerInit(entity)
	if entity.Variant == AMLVariants.SCREAMER then
		local data = entity:GetData()
		
		entity:ToNPC()
		entity.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
		entity.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
		entity.SplatColor = Color(0.4,0.4,0.4, 1, 0.1,0.1,0.1)

		data.state = States.Appear
		data.soundTimer = (math.random(Settings.SoundTimer[1], Settings.SoundTimer[2])) / 2
	end
end

function this:screamerUpdate(entity)
	if entity.Variant == AMLVariants.SCREAMER then
		local sprite = entity:GetSprite()
		local data = entity:GetData()
		local target = entity:GetPlayerTarget()

		
		if data.state == States.Appear or data.state == nil then
			sprite:Play("Idle", true)
			data.state = States.Moving
			entity.Velocity = Vector.Zero


		elseif data.state == States.Moving or data.state == States.Angry then
			local speed = Settings.MoveSpeed
			local suffix = ""

			if data.state == States.Angry then
				speed = Settings.AngrySpeed
				suffix = "Angry"
				
				-- Slowing aura
				if entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
					for _,v in pairs(Isaac.GetRoomEntities()) do
						if v.Type > 9 and v.Type < 1000 and entity.Position:Distance(v.Position) <= Settings.Range then
							v:AddSlowing(EntityRef(entity), -1, 0.8, Color(0.6,0.6,0.6, 1))
						end
					end

				else
					for i = 0, game:GetNumPlayers() do
						local player = Isaac.GetPlayer(i)
						
						if entity.Position:Distance(player.Position) <= Settings.Range then
							player:AddSlowing(EntityRef(entity), -1, 0.8, Color(1,1,1, 1))
							player:SetColor(Color(0.6,0.6,0.6, 1), 1, 1, false, false)
						end
					end
				end
			end


			-- Movement
			if entity:HasEntityFlags(EntityFlag.FLAG_FEAR) or entity:HasEntityFlags(EntityFlag.FLAG_SHRINK) then
				speed = -speed
			end

			if entity:HasEntityFlags(EntityFlag.FLAG_CONFUSION) then
				entity.Pathfinder:MoveRandomly(false)

			else
				if entity.Pathfinder:HasPathToPos(target.Position) then
					if game:GetRoom():CheckLine(entity.Position, target.Position, 0, 0, false, false) then
						entity.Velocity = (entity.Velocity + ((target.Position - entity.Position):Normalized() * speed - entity.Velocity) * 0.25)
					
					else
						entity.Pathfinder:FindGridPath(target.Position, speed / 6, 500, false)
					end
				
				else
					entity.Velocity = (entity.Velocity + (Vector.Zero - entity.Velocity) * 0.25)
				end
			end
			

			-- Get animation direction
			local angleDegrees = entity.Velocity:GetAngleDegrees()

			if angleDegrees > -45 and angleDegrees < 45 then
				data.facing = "Right"
			elseif angleDegrees >= 45 and angleDegrees <= 135 then
				data.facing = "Down"
			elseif angleDegrees < -45 and angleDegrees > -135 then
				data.facing = "Up"
			else
				data.facing = "Left"
			end


			-- Walking animation
			if entity.Velocity:Length() > 0.1 then
				if not sprite:IsPlaying("Walk" .. data.facing .. suffix) then
					sprite:Play("Walk" .. data.facing .. suffix, true)
				end
			else
				sprite:Play("Idle" .. suffix, true)
			end


			if entity.Position:Distance(target.Position) <= Settings.Range and data.state == States.Moving then
				data.state = States.Scream
			end
			
			if data.soundTimer <= 0 then
				entity:PlaySound(SoundEffect.SOUND_ZOMBIE_WALKER_KID, 1, 0, false, 0.75)
				data.soundTimer = math.random(Settings.SoundTimer[1], Settings.SoundTimer[2])
			else
				data.soundTimer = data.soundTimer - 1
			end


		elseif data.state == States.Scream then
			if not sprite:IsPlaying("Scream") then
				entity.Velocity = Vector.Zero
				sprite:Play("Scream", true)
			end
			
			if sprite:IsEventTriggered("Scream") or sprite:IsEventTriggered("Effect") then
				if sprite:IsEventTriggered("Scream") then
					-- Frighten close players
					if not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
						for i = 0, game:GetNumPlayers() do
							local player = Isaac.GetPlayer(i)
							
							if entity.Position:Distance(player.Position) <= Settings.Range then
								player:AddFear(EntityRef(entity), 45)
							end
						end
					end
					
					entity:PlaySound(Isaac.GetSoundIdByName("Screamer Scream"), 2, 0, false, 1)
					game:ShakeScreen(36)
					
					-- Alert Nightwatches (state 2 = Alert, state 3 = AlertNoEffect)
					for _,v in pairs(Isaac.GetRoomEntities()) do
						if v.Type == EntityType.ENTITY_NIGHTWATCH and v:GetData().state ~= 2 and v:GetData().state ~= 3 then
							v:GetData().state = 2
							break
						end
					end
				end
				
				-- Ring effect
				local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SIREN_RING, 867, entity.Position, Vector.Zero, entity):ToEffect()
				effect:FollowParent(entity)
				effect:GetSprite().Offset = Vector(0, -44)
				effect:GetSprite().Scale = Vector(0.75, 0.75)
			end
			
			if sprite:GetFrame() == 47 then
				data.state = States.Angry

				-- Slowing aura
				local aura = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SCREAMER_AURA, 0, entity.Position, Vector.Zero, entity):ToEffect()
				aura.Parent = entity
				aura:GetSprite():Play("FadeIn", true)
				aura.DepthOffset = -1000
			end
		end
		
		if entity:HasMortalDamage() then -- using the actual entity state is unreliable but this works good enough (creates gibs before the death animation though)
			entity.State = NpcState.STATE_DEATH
		end
	end
end



-- Slowing aura
function this:screamerAuraUpdate(effect)
	if effect.Parent ~= nil then
		local sprite = effect:GetSprite()

		effect:FollowParent(effect.Parent)

		if sprite:IsPlaying("FadeIn") and sprite:GetFrame() == 11 then
			sprite:Play("Idle", true)
		end

		if effect.Parent:HasMortalDamage() then
			if not sprite:IsPlaying("FadeOut") then
				sprite:Play("FadeOut", true)
			end
			if sprite:GetFrame() == 9 then
				effect:Remove()
			end
		end
	end
end



function this:Init()
    AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.screamerInit, EntityType.ENTITY_AML)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.screamerUpdate, EntityType.ENTITY_AML)
	
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, this.screamerAuraUpdate, EffectVariant.SCREAMER_AURA)
end



return this