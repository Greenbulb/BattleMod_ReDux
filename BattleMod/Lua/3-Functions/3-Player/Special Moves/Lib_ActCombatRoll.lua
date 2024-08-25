local B = CBW_Battle
local cooldown = TICRATE * 9/2
local cooldown2 = TICRATE * 3
local xythrust = 38
local zthrust = 9
local dropspeed = 20

B.Action.CombatRoll = function(mo,doaction)
	local player = mo.player

	//Conditions
	local bouncing = player.pflags&PF_BOUNCING
	local activate = player.actiontime == 0 and doaction == 1
	local thrust_trigger = activate and not(bouncing)
	local springdrop_trigger = activate and bouncing
	local drop_state = player.actionstate == 1 and bouncing
		and P_MobjFlip(mo)*mo.momz < 0
	local thrust_state = player.actiontime and mo.state == S_PLAY_ROLL
		and not(P_IsObjectOnGround(mo)) and player.actiontime < 18
	
	//Properties
	player.actiontext = "Combat Roll"
	player.actionrings = 10
	if player.pflags&PF_BOUNCING
		player.actiontext = "Spring Drop"
		player.actionrings = 5
	end
	
	//Perform Thrust
	if thrust_trigger
		//Apply cost, cooldown, state
		B.PayRings(player)
		player.actionstate = 2
		player.actiontime = 1
		B.ApplyCooldown(player,cooldown)
		player.drawangle = mo.angle
		//Apply momentum
		B.ZLaunch(mo,zthrust*FRACUNIT,false)
		P_InstaThrust(mo,mo.angle,xythrust*mo.scale)
		//Apply midair state
		player.pflags = ($|PF_JUMPED) &~ (PF_NOJUMPDAMAGE|PF_THOKKED)
		mo.state = S_PLAY_ROLL
		player.airgun = false
		//Do effects
		S_StartSound(mo,sfx_zoom)
		for n = 0,3
			local dust = P_SpawnMobjFromMobj(mo,0,0,0,MT_SPINDUST)
			local angle = (180+P_RandomRange(-60,60))*ANG1+mo.angle
			local speed = mo.scale*P_RandomRange(5,10)
			P_InstaThrust(dust,angle,speed)
		end
		player.noshieldactive = -1
		return
	end
	
 	//Perform spring drop
	if springdrop_trigger
		//Apply cost, cooldown, state
		B.PayRings(player)
		player.actionstate = 1
		player.actiontime = 1
		//Apply momentum
		mo.momx = $/2
		mo.momy = $/2
		B.ZLaunch(mo,-dropspeed*FRACUNIT,false)
		//Effects
		S_StartSound(mo,sfx_zoom)
		P_SpawnParaloop(mo.x,mo.y,mo.z,mo.scale*128,16,MT_DUST,ANGLE_90,nil,true)
		return
	end
	
	if thrust_state
		player.drawangle = mo.angle
	end
	
	//Drop bombs
	if player.actionstate == 1
	and bouncing
	and (mo.eflags & MFE_JUSTHITFLOOR)
	B.ApplyCooldown(player,cooldown2)
		player.nobombjump = true
		for n = 0, 4
			local bomb = B.throwbomb(mo)
			if bomb and bomb.valid then
				P_InstaThrust(bomb,ANGLE_45+mo.angle+(ANGLE_90*n),mo.scale*4)
				P_SetObjectMomZ(bomb, mo.scale*8)
				bomb.flags = $ &~ (MF_GRENADEBOUNCE)
				bomb.bombtype = 0
			end
		end
		player.actiontime = 0
		player.actionstate = 0
	end

	//Reset state
	if not(drop_state or thrust_state or (mo.eflags & MFE_SPRUNG))
		player.actiontime = 0
		player.actionstate = 0
	else //Afterimage
		player.actiontime = $+1
		if player.actiontime%8
			P_SpawnGhostMobj(mo)
		end
	end
end

local function fanghop(player)
	local mo = player.mo
	B.ZLaunch(mo, 7 * mo.scale, false)
	mo.state = S_PLAY_JUMP
	mo.momx = $ * -2/3
	mo.momy = $ * -2/3
	player.actionstate = 0
	player.actiontime = 0
	player.pflags = ($ | (PF_JUMPED | PF_STARTJUMP | PF_NOJUMPDAMAGE)) & ~PF_THOKKED
	player.powers[pw_nocontrol] = 16
end

local function iscombatroll(player)
	if not (player and player.valid and player.playerstate == PST_LIVE)
		or not player.mo
		or not (player.actiontime and player.mo.state == S_PLAY_ROLL)
		or not player.mo.health
		return false
	end
	return true
end

B.Fang_PreCollide = function(n1,n2,plr,mo,atk,def,weight,hurt,pain,ground,angle,thrust,thrust2,collisiontype)
	if iscombatroll(plr[n1])
		plr[n1].fangmarker = true
	end
end

B.Fang_PostCollide = function(n1,n2,plr,mo,atk,def,weight,hurt,pain,ground,angle,thrust,thrust2,collisiontype)
	if plr[n1] and plr[n1].fangmarker
		plr[n1].fangmarker = nil
	end
end

B.Fang_Collide = function(n1,n2,plr,mo,atk,def,weight,hurt,pain,ground,angle,thrust,thrust2,collisiontype)
	if not (plr[n1] and plr[n1].fangmarker)
		return false
	end
	if (hurt != 1 and n1 == 1) or (hurt != -1 and n1 == 2)
		if not (plr[n2] and plr[n2].fangmarker)
			fanghop(plr[n1])
		end
		if plr[n2]
			B.DoPlayerTumble(plr[n2], 24, angle[n1], mo[n1].scale*3, true)
		end
		P_InstaThrust(mo[n2], angle[n2], mo[n1].scale * 5)
		B.ZLaunch(mo[n2], 7 * mo[n2].scale, false)
		return true
	end
end

B.Action.CombatRoll_Priority = function(player)
	local mo = player.mo
	if not (mo and mo.valid) return end
	
	local bouncing = player.pflags&PF_BOUNCING
	local drop_state = player.actionstate == 1 and bouncing
		and P_MobjFlip(mo)*mo.momz < 0
	local thrust_state = player.actiontime and mo.state == S_PLAY_ROLL
		and not(P_IsObjectOnGround(mo)) and player.actiontime < 20
	
	if player.actionstate == 1
		B.SetPriority(player,0,1,"fang_springdrop",2,3,"spring drop")
	elseif player.actionstate == 2
		B.SetPriority(player,1,1,nil,1,1,"combat roll")
	end
end