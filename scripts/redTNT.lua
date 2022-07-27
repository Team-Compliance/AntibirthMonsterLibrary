local mod = AntiMonsterLib
local game = Game()

-- All functionality basically
function mod:RedTNTUpdate()
	local room = game:GetRoom()
	for ind = 1, room:GetGridSize() do
		local gridEnt = room:GetGridEntity(ind)
		if gridEnt then
			local tnt = gridEnt:ToTNT()
			if tnt then
				if tnt:GetVariant() == AMLVariants.RED_TNT then
					if tnt.State == 0 then
						for i, entities in ipairs(Isaac.FindInRadius(tnt.Position, 30, EntityPartition.ENEMY | EntityPartition.PLAYER)) do
							tnt.State = 4
						end
					else
						tnt.State = 4
					end
				end
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.RedTNTUpdate)

-- For the sprite
function mod:RedTNTRender()
	local room = game:GetRoom()
	for ind = 1, room:GetGridSize() do
		local gridEnt = room:GetGridEntity(ind)
		if gridEnt then
			local tnt = gridEnt:ToTNT()
			if tnt then
				if tnt:GetVariant() == AMLVariants.RED_TNT then
					local sprite = tnt:GetSprite()
					if sprite:GetFilename() ~= "gfx/grid/grid_redtnt.anm2" then
						sprite:Load("gfx/grid/grid_redtnt.anm2", true)
					end
				end
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.RedTNTRender)


-- Replaces the old entity based red tnt with the new grid
function mod:ReplaceOldRedTNT(entity)
	local room = game:GetRoom()
	if entity.Type == EntityType.ENTITY_AML and entity.Variant == AMLVariants.RED_TNT then
		local index = room:GetClampedGridIndex(entity.Position)
		entity:Remove()
		room:SpawnGridEntity(index, GridEntityType.GRID_TNT, AMLVariants.RED_TNT, entity.InitSeed, 0)
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.ReplaceOldRedTNT)
