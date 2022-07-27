local mod = AntiMonsterLib
local game = Game()

function mod:RedTNTCollision()

end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.RedTNTCollision)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.RedTNTCollision)

function mod:RedTNTUpdate()
	local room = game:GetRoom()
	for ind = 1, room:GetGridSize() do
		local gridEnt = room:GetGridEntity(ind)
		if gridEnt then
			local tnt = gridEnt:ToTNT()
			if tnt then
				if tnt:GetVariant() == AMLVariants.RED_TNT then
					local sprite = tnt:GetSprite()
					sprite:ReplaceSpritesheet(0, "gfx/grid/grid_redtnt.png")
					sprite:LoadGraphics()
					
					if tnt.State >= 1 then
						tnt.State = 4
					end
				end
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.RedTNTUpdate)

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
