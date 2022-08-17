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