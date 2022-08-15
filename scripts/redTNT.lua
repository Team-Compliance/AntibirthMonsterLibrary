local mod = AntiMonsterLib
local game = Game()

-- Just check collision and damage.
function mod:RedTNTCollision(tnt, collider, low)
	if tnt.Variant == AMLVariants.RED_TNT then
		if collider:ToPlayer() or collider:ToNPC() then
			tnt.HitPoints = 1
		end
	end
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.RedTNTCollision, EntityType.ENTITY_MOVABLE_TNT)
function mod:RedTNTDamage(tnt, amount, flags, source, frames)
	if tnt.Variant == AMLVariants.RED_TNT then
		tnt.HitPoints = 1
	end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.RedTNTDamage, EntityType.ENTITY_MOVABLE_TNT)
