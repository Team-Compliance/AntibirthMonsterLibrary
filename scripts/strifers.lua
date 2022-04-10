if not StandaloneStrifers then
local this = {}
local game = Game()



local Strifer = {
	SPEED = 5.35,
	ATTACKING_SPEED = 4,
	COOLDOWN = 60,
	SHOT_SPEED = 11,
	ATTACK_SIDE_RANGE = 78,
	MAX_TARGET_RANGE = 338
}



-- Functions
function Lerp(first,second,percent)
	return (first + (second - first) * percent)
end


function StriferTurnAround(entity)
	local data = entity:GetData()

	if data.movetype == "vertical" then
		data.vector = Vector(data.vector.X, -data.vector.Y)
	elseif data.movetype == "horizontal" then
		data.vector = Vector(-data.vector.X, data.vector.Y)
	end
	
	data.delay = 7
end



function this:StriferInit(entity)
	local data = entity:GetData()
	local sprite = entity:GetSprite()
	local level = game:GetLevel()
	local stage = level:GetStage()
	
	entity:ToNPC()
	entity.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL


	-- Set Variables
	local cdRNG = RNG()
	cdRNG:SetSeed(Random(), 839)
	entity.ProjectileCooldown = cdRNG:RandomInt(Strifer.COOLDOWN - 20) + 20 -- Set random starting cooldown for attack (minimum is 20)

	data.currSpeed = Strifer.SPEED
	data.shot = 0
	entity:AddEntityFlags(EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)

	data.altSkin = ""
	if (stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2) and level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B then
		data.altSkin = "_gehenna"
	end
	

	-- Set spritesheets
	if data.altSkin ~= "" then
		for i = 0, sprite:GetLayerCount() - 1 do
			sprite:ReplaceSpritesheet(i, "gfx/monsters/repentance/839.000_strifer" .. data.altSkin .. ".png")
		end
		sprite:LoadGraphics()
	end
end



function this:StriferUpdate(entity)
	local data = entity:GetData()
	local sprite = entity:GetSprite()
	local target = entity:GetPlayerTarget()
	local moveto = entity.TargetPosition


	-- Determine movement directions
	function setmovement()
		if entity.Variant == 0 or entity.Variant == 2 then
			data.movetype = "vertical"
			
		elseif entity.Variant == 1 or entity.Variant == 3 then
			data.movetype = "horizontal"
		end
	end
	
	-- Determine attack direction
	function setfacing()
		if     entity.Variant == 0 then data.facing = "Left"
		elseif entity.Variant == 1 then data.facing = "Up"
		elseif entity.Variant == 2 then data.facing = "Right"
		elseif entity.Variant == 3 then data.facing = "Down"
		end
	end


	-- Set variant if direction is not set
	if data.facing == nil or data.movetype == nil then
		local champid = entity:GetChampionColorIdx()
		local enterd = game:GetLevel().EnterDoor
			
		-- Left / Right
		if entity.Variant == 4 or (entity.Variant == 6 and enterd % 2 == 0) then -- All left and right doors have an even numbered ID
			if target.Position.X <= entity.Position.X then
				entity:Morph(839, 0, 0, champid)

			else -- >=
				entity:Morph(839, 2, 0, champid)
			end

		-- Up / Down
		elseif entity.Variant == 5 or (entity.Variant == 6 and enterd % 2 ~= 0) then
			if target.Position.Y <= entity.Position.Y then
				entity:Morph(839, 1, 0, champid)

			else -- >=
				entity:Morph(839, 3, 0, champid)
			end
		end
		
		setmovement()
		setfacing()
	end


	-- Sprite
	entity:AnimWalkFrame("WalkHori", "WalkVert", 0.1)
	
	if data.facing == "Left" then -- Makes sure the head doesn't flip from tear knockback
		sprite.FlipX = true
	elseif data.facing == "Right" then
		sprite.FlipX = false
	end



	-- Set random starting direction if it doesn't have one
	if not data.vector then
		local dirRNG = RNG()
		dirRNG:SetSeed(Random(), 839)
		
		local startDir = 1
		if dirRNG:RandomInt(2) == 1 then
			startDir = -1
		end

		if data.movetype == "vertical" then
			data.vector = Vector(0, startDir * Strifer.SPEED)
		elseif data.movetype == "horizontal" then
			data.vector = Vector(startDir * Strifer.SPEED, 0)
		end
	end


	-- Get target position
	if data.movetype == "vertical" then
		moveto = Vector(entity.Position.X, target.Position.Y)
	elseif data.movetype == "horizontal" then
		moveto = Vector(target.Position.X, entity.Position.Y)
	end
	
	
	-- Check if target is close enough
	function StriferInRange(side)
		local data = entity:GetData()

		if data.movetype == "vertical" then
			if entity.Position.Y <= moveto.Y + side and entity.Position.Y >= moveto.Y - side then
				if data.facing == "Left" and target.Position.X > (entity.Position.X - Strifer.MAX_TARGET_RANGE) and target.Position.X < entity.Position.X
				or data.facing == "Right" and target.Position.X < (entity.Position.X + Strifer.MAX_TARGET_RANGE) and target.Position.X > entity.Position.X then
					return true
				end
			end
			
		elseif data.movetype == "horizontal" then
			if entity.Position.X <= moveto.X + side and entity.Position.X >= moveto.X - side then
				if data.facing == "Up" and target.Position.Y > (entity.Position.Y - Strifer.MAX_TARGET_RANGE) and target.Position.Y < entity.Position.Y
				or data.facing == "Down" and target.Position.Y < (entity.Position.Y + Strifer.MAX_TARGET_RANGE) and target.Position.Y > entity.Position.Y then
					return true
				end
			end
		end
	end
	
	
	-- Fix for them getting stuck sometimes
	if entity:CollidesWithGrid() and not data.delay then
		StriferTurnAround(entity)
	end

	if not data.delay then
		-- Move towards target if it's close enough
		if StriferInRange(Strifer.MAX_TARGET_RANGE) == true and entity.Position:Distance(moveto) > 12 and not entity:HasEntityFlags(EntityFlag.FLAG_CONFUSION) then
			if entity:HasEntityFlags(EntityFlag.FLAG_FEAR) or entity:HasEntityFlags(EntityFlag.FLAG_SHRINK) then
				data.vector = (moveto - entity.Position):Normalized() * -data.currSpeed

			else
				data.vector = (moveto - entity.Position):Normalized() * data.currSpeed
			end
		end
	
		-- Turn around when colliding with a grid entity
		if entity:CollidesWithGrid() then
			StriferTurnAround(entity)
		end

	else
		data.delay = data.delay - 1
		
		if data.delay <= 0 then
			data.delay = nil
		end
	end

	entity.Velocity = Lerp(entity.Velocity, data.vector, 0.25)
	

	-- Attacking
	if entity.ProjectileCooldown > 0 then
		if not sprite:IsOverlayPlaying("Head" .. data.facing) then
			sprite:PlayOverlay("Head" .. data.facing)
		end
		
		entity.ProjectileCooldown = entity.ProjectileCooldown - 1
	
	else
		if StriferInRange(Strifer.ATTACK_SIDE_RANGE) and game:GetRoom():CheckLine(entity.Position, target.Position, 3, 0, false, false) then
			if not sprite:IsOverlayPlaying("Attack" .. data.facing) then
				sprite:PlayOverlay("Attack" .. data.facing)
			end
		end


		if sprite:GetOverlayFrame() == 7 then
			entity:PlaySound(SoundEffect.SOUND_SHAKEY_KID_ROAR, 1, 1, false, 1)
			data.currSpeed = Strifer.ATTACKING_SPEED
			
		elseif sprite:GetOverlayFrame() == 8 or sprite:GetOverlayFrame() == 12 or sprite:GetOverlayFrame() == 16 or sprite:GetOverlayFrame() == 20 then
			if data.shot ~= sprite:GetOverlayFrame() then -- stops them from shooting twice when slowed
				local params = ProjectileParams()
				params.FallingSpeedModifier = 0.3
				
				local shootx = 0
				local shooty = 0
				
				if     data.facing == "Left"  then shootx = -Strifer.SHOT_SPEED
				elseif data.facing == "Up"    then shooty = -Strifer.SHOT_SPEED
				elseif data.facing == "Right" then shootx =  Strifer.SHOT_SPEED
				elseif data.facing == "Down"  then shooty =  Strifer.SHOT_SPEED
				end
				
				entity:FireProjectiles(entity.Position, Vector(shootx, shooty), 0, params)
				data.shot = sprite:GetOverlayFrame()
			end
			
		elseif sprite:GetOverlayFrame() == 24 then
			data.currSpeed = Strifer.SPEED
		end

		if sprite:IsOverlayFinished("Attack" .. data.facing) then
			entity.ProjectileCooldown = Strifer.COOLDOWN
		end
	end
end



function this:StriferCollision(entity, target, cum)
	local data = entity:GetData()

	-- Turn around when colliding with another enemy
	if not data.delay and target:IsActiveEnemy(false) and target.Type ~= EntityType.ENTITY_GRUDGE then
		StriferTurnAround(entity)

	-- Fix for them not working properly with Grudges
	elseif target.Type == EntityType.ENTITY_GRUDGE then
		entity.Velocity = target.Velocity

		if entity:CollidesWithGrid() then
			entity:Kill()
		end
	end
end



function this:Init()
	AntiMonsterLib:AddCallback(ModCallbacks.MC_POST_NPC_INIT, this.StriferInit, 839)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_NPC_UPDATE, this.StriferUpdate, 839)
    AntiMonsterLib:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, this.StriferCollision, 839)
end



return this
end