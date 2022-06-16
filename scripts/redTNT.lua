local mod = AntiMonsterLib
local game = Game()

local RedTNTRoomRecord = {}



-- Get red TNT room record
function mod:GetRedTNTs()
    local room_index = Game():GetLevel():GetCurrentRoomIndex()
	
	-- Get red TNT spawns
    if game:GetRoom():IsFirstVisit() then
		local redtnt_table = {}
		
        for _,v in pairs(Isaac.GetRoomEntities()) do
			if v.Type == EntityType.ENTITY_AML and v.Variant == AMLVariants.RED_TNT then
				table.insert(redtnt_table, v.Position)
			end
        end
		RedTNTRoomRecord[room_index] = redtnt_table
		
	-- Respawn red TNTs
    else
		if RedTNTRoomRecord[room_index] ~= nil then
			for _,v in pairs(RedTNTRoomRecord[room_index]) do
				Isaac.Spawn(EntityType.ENTITY_AML, AMLVariants.RED_TNT, 0, v, Vector.Zero, nil)
			end
		end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.GetRedTNTs)

-- Reset red TNT record upon new stage entry
function mod:RedTNTClearRecord()
	RedTNTRoomRecord = {}
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.RedTNTClearRecord)



-- Don't take damage
function mod:RedTNTDamage(entity, amount, dmg_flags)
	if entity.Variant == AMLVariants.RED_TNT then
		return false
	end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.RedTNTDamage, EntityType.ENTITY_AML)

-- Explode on collision
function mod:RedTNTCollision(entity, collider, low)
	if entity.Variant == AMLVariants.RED_TNT then
		local room_index = game:GetLevel():GetCurrentRoomIndex()
		
		Isaac.Explode(entity.Position, entity, 100)
		entity.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		entity:GetSprite():Play("Blown")
		
		if RedTNTRoomRecord[room_index] ~= nil then
			for i,v in pairs(RedTNTRoomRecord[room_index]) do 
				if v == entity.Position then
					table.remove(RedTNTRoomRecord[room_index], i)
				end
			end
		end
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, mod.RedTNTCollision, EntityType.ENTITY_AML)