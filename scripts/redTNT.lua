local mod = AntiMonsterLib
local game = Game()

-- Just check collision.
function mod:RedTNTCollision(tnt, collider, low)
	if tnt.Variant == AMLVariants.RED_TNT then
		tnt:Die()
		return false
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.RedTNTCollision, EntityType.ENTITY_MOVABLE_TNT)

-- Set the grid path at the location so entities don't pathfind through it
function mod:RedTNTUpdate(tnt)
	if tnt.Variant == AMLVariants.RED_TNT and tnt.HitPoints == 4 then
		local room = game:GetRoom()
		room:SetGridPath(room:GetGridIndex(tnt.Position), 900)
	end
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.RedTNTUpdate, EntityType.ENTITY_MOVABLE_TNT)