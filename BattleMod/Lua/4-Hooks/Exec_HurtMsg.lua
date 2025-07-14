local B = CBW_Battle

local function battle_hurtmsg(player,inflictor,source) 
    if not (inflictor and inflictor.valid) return end
    if inflictor.type == MT_PLAYER
        local attacktext = inflictor.player.battle_hurttxt
        if attacktext
            print(B.CustomHurtMessage(player,inflictor,attacktext)) 
            return true
        end
    else
        if not (inflictor.name or inflictor.info.name) return end
        local name
        if inflictor.name
            name = inflictor.name
        elseif inflictor.info.name
            name = inflictor.info.name
        end
        print(B.CustomHurtMessage(player,source,name))
        return true
    end
end

addHook("HurtMsg",battle_hurtmsg,NULL)
