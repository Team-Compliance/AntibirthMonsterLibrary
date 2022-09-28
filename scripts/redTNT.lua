local mod = AntiMonsterLib
local game = Game()

-- Just check collision.
function mod:RedTNTCollision(tnt)
	if tnt.Variant == AMLVariants.RED_TNT then
		tnt:Die()
		return false
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.RedTNTCollision, EntityType.ENTITY_MOVABLE_TNT)

-- Also check for any kind of damage just in case
function mod:RedTNTDamage(tnt)
	if tnt.Variant == AMLVariants.RED_TNT then
		tnt:Die()
	end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.RedTNTDamage, EntityType.ENTITY_MOVABLE_TNT)

function mod:RedTNTUpdate(tnt)
	if tnt.Variant == AMLVariants.RED_TNT and tnt.HitPoints == tnt.MaxHitPoints then
		-- Set the grid path at the location so entities don't pathfind through it
		local room = game:GetRoom()
		room:SetGridPath(room:GetGridIndex(tnt.Position), 900)

		-- Projectiles aren't detected on collision so we have to manually account for them
		for _, entity in pairs(Isaac.FindInRadius(tnt.Position, tnt.Size, EntityPartition.BULLET)) do
			entity:Die()
			tnt.HitPoints = 0.5
		end
	end
end
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.RedTNTUpdate, EntityType.ENTITY_MOVABLE_TNT)