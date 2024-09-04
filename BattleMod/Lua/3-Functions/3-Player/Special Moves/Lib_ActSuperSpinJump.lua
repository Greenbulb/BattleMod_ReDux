local B = CBW_Battle
local cooldown1 = TICRATE
local cooldown2 = TICRATE * 9/4 //2.25s
local cooldown3 = TICRATE * 4
local state_superspinjump = 1
local state_groundpound_rise = 2
local state_groundpound_fall = 3
local state_superspinwave = 10 // new
local jumpthrust = 42*FRACUNIT
local recoilthrust = 22*FRACUNIT
local pound_startthrust = 10*FRACUNIT
local pound_downaccel = FRACUNIT*4//4
local jumpfriction = FRACUNIT*9/10
local poundfriction = FRACUNIT
local reboundthrust = 13

B.Action.SuperSpinJump_Priority = function(player)
	local mo = player.mo
	if not (mo and mo.valid) return end

	local spinwavereq = (player.mo.state == S_PLAY_SPINDASH and player.dashspeed > (player.maxdash/5*3))

	if not(spinwavereq) and player.textflash_flashing then
		player.actiontext = B.TextFlash(player.actiontext, true, player)
	end

	if player.actionstate == state_superspinjump then
		B.SetPriority(player,2,2,nil,2,2,"super spin jump")
	elseif player.actionstate == state_groundpound_rise then
		B.SetPriority(player,1,1,nil,1,1,"rising ground pound")
	elseif player.actionstate == state_groundpound_fall then
		B.SetPriority(player,1,1,"stomp",2,2,"ground pound")
	elseif player.actionstate == state_superspinwave then
		B.SetPriority(player,0,0,nil,0,0,"spin wave recoil")
	end
end


	

B.Action.SuperSpinJump=function(mo,doaction)
	local player = mo.player

	if player.actionstate == 0 and not(player.exiting) then
		mo.spritexscale = FRACUNIT
		mo.spriteyscale = FRACUNIT
	end
	
	if not(B.CanDoAction(player)) then
		player.actionstate = 0
		if not player.exiting then
			mo.spritexscale = FRACUNIT
			mo.spriteyscale = FRACUNIT
		end
	return end

	local spinwavereq = (player.mo.state == S_PLAY_SPINDASH and player.dashspeed > (player.maxdash/5*3))


	--print(string.format("%.4f", player.dashspeed))
	//Action info
	if spinwavereq then
		if (player.textflash_flashing) then --wittle hacky
			if (leveltime % 8) == 0 then
				B.SpawnFlash(mo, 10, true)
			end
		else
			B.SpawnFlash(mo, 10, true)
			B.teamSound(mo, player, sfx_spwvt, sfx_spwve, 255, false)
		end
		player.actiontext = B.TextFlash("Spin Wave", (doaction == 1), player)
		player.actionrings = 10
	elseif P_IsObjectOnGround(mo) or player.mo.state == S_PLAY_LEDGE_GRAB or player.actionstate == state_superspinjump then
		player.actiontext = "Super Spin Jump"
		player.actionrings = 10
	else
		player.actiontext = "Ground Pound"
		player.actionrings = 10
	end
	player.action2text = nil
	if player.actionstate != 0 then player.canguard = false end
	
	local water = B.WaterFactor(mo)
	local thrust
	local jumpflags = (player.pflags|PF_JUMPED|PF_THOKKED)&~(PF_STARTJUMP|PF_NOJUMPDAMAGE|PF_GLIDING|PF_BOUNCING|PF_SPINNING)

	//Neutral
	if player.actionstate == 0
		player.squashstretch = 0
		if doaction == 1 then
			B.PayRings(player)
			//Do spin wave if charging a spin dash
			if mo.state == S_PLAY_SPINDASH and player.dashspeed > (player.maxdash/5*3) then
				player.actionstate = state_superspinwave
				thrust = FixedMul((recoilthrust),player.jumpfactor)
				P_SetObjectMomZ(mo,thrust,true) //Inherit platform momentum
				thrust = ($/FRACUNIT)*player.mo.scale// need scale bacause thrust is dumb
				P_Thrust(mo,(mo.angle-ANGLE_180),thrust/2)// recoil back
				player.pflags = jumpflags
				mo.state = S_PLAY_ROLL
				player.secondjump = 0
				player.canguard = false
				player.lockmove = true
				// wave projectile
				local spinwave = P_SpawnMobjFromMobj(player.mo, FixedMul(player.mo.radius, cos(player.mo.angle)),
				FixedMul(player.mo.radius, sin(player.mo.angle)), 0, MT_SUPERSPINWAVE)
				spinwave.target = player.mo
				spinwave.spawntime = 0
				local spinwave_speed = player.dashspeed+1*FRACUNIT
				spinwave_speed = ($/FRACUNIT)*player.mo.scale
				spinwave.startingspeed = spinwave_speed
				spinwave.setpostion = true
				spinwave.angle = player.mo.angle
				spinwave.color = SKINCOLOR_SKY

				if player.rings+player.actionrings < player.actionrings then
					player.cooldown = cooldown2
				else
					B.ApplyCooldown(player, cooldown2)
				end

				if G_GametypeHasTeams() then
					spinwave.color = player.skincolor
				end
			elseif P_IsObjectOnGround(mo) or player.mo.state == S_PLAY_LEDGE_GRAB then //Do high jump
				mo.spritexscale = FRACUNIT * 2/3
				mo.spriteyscale = FRACUNIT * 3/2
				player.squashstretch = 1
				
				player.actionstate = state_superspinjump
-- 				P_DoJump(player,true)
				thrust = FixedMul(jumpthrust,player.jumpfactor)
				P_SetObjectMomZ(mo,thrust,true) //Inherit platform momentum
-- 				P_InstaThrust(mo,mo.angle,0)
				S_StartSound(mo,sfx_s3k3c)
				S_StartSound(mo,sfx_kc5b)
				player.pflags = jumpflags
				mo.state = S_PLAY_ROLL
				player.secondjump = 0
				player.canguard = false
				--B.ApplyCooldown(player,cooldown1)
			else //Do ground pound
				B.ApplyCooldown(player,cooldown2)
				thrust = pound_startthrust/water
				player.actionstate = state_groundpound_rise
				P_SetObjectMomZ(mo,thrust,false)
				S_StartSound(mo,sfx_zoom)
				mo.state = S_PLAY_ROLL
				player.pflags = jumpflags
				player.secondjump = 0
				player.squashstretch = 1
			end
		end
	return end
	
	//Ground pound phase 1
	if player.actionstate == state_groundpound_rise 
		B.ControlThrust(mo,poundfriction,nil,FRACUNIT,FixedMul(player.actionspd,mo.scale))
		P_SetObjectMomZ(mo,-pound_downaccel/water,true)
		if mo.momz*P_MobjFlip(mo) < 0 then //If we're moving upward, then move onto the second phase
			player.actionstate = state_groundpound_fall
		end
		player.actiontime = abs(mo.momz)
	end

	//Ground pound phase 2
	if player.actionstate == state_groundpound_fall 
		B.ControlThrust(mo,poundfriction,nil,FRACUNIT,FixedMul(player.actionspd,mo.scale))
		mo.coyoteTime = 0
		if mo.momz*P_MobjFlip(mo) > 0 then //If we're moving upward, then something must have interrupted us.
			player.actionstate = (mo.eflags & MFE_SPRUNG) and $ or 0
			if mo.pushed_last then
				player.pflags = $|PF_JUMPED|PF_STARTJUMP|PF_NOJUMPDAMAGE&~PF_SPINNING|PF_JUMPED
				mo.state = S_PLAY_SPRING
			elseif not (mo.eflags & MFE_SPRUNG) then
				P_SetObjectMomZ(mo,mo.momz*3/4)
				B.ResetPlayerProperties(player,true,false)
				if player.cmd.buttons & BT_JUMP then player.pflags = $|PF_STARTJUMP end
			end
		else
			P_SetObjectMomZ(mo,-pound_downaccel/water,true)
			if mo.eflags&MFE_JUSTHITFLOOR then //We have hit a surface
				player.lockjumpframe = 2
				player.powers[pw_nocontrol] = $ or 2
				B.ApplyCooldown(player,cooldown2)//
				
				if player == displayplayer
					P_StartQuake(6*FRACUNIT, 3)
				end
				
				S_StartSound(mo,sfx_s3k5f)
				local blastspeed = 4
				local fuse = 10
				
				//Create projectile blast
				for n = 0, 23
					local p = P_SPMAngle(mo,MT_GROUNDPOUND,mo.angle+n*ANG15,0)
					if p and p.valid then
						p.momz = mo.scale*P_MobjFlip(mo)*blastspeed/water
						p.fuse = fuse
					end
				end
					
				P_InstaThrust(mo,R_PointToAngle2(0,0,mo.momx,mo.momy),FixedHypot(mo.momx,mo.momy)/8)
				B.ZLaunch(mo,reboundthrust*FRACUNIT,true)
				mo.state = S_PLAY_SPRING
				player.pflags = ($|PF_THOKKED)&~PF_SPINNING
				B.ResetPlayerProperties(player,false,false)
			else
				player.actiontime = abs(mo.momz)
				mo.spritexscale = max(FRACUNIT * 3/4, min($ - FRACUNIT/100, FRACUNIT))
				mo.spriteyscale = max(FRACUNIT, min($ + FRACUNIT/100, FRACUNIT*4/3))
			end
		end
	end

	//SuperSpinJump state
	if player.actionstate == state_superspinjump 
		B.ControlThrust(mo,FRACUNIT,nil,jumpfriction,nil)
		mo.spritexscale = max(FRACUNIT * 4/5, min($ + FRACUNIT/30, FRACUNIT))
		mo.spriteyscale = max(FRACUNIT, min($ - FRACUNIT/30, FRACUNIT * 5/4))
		
		//Restore ability after end-rising
		if mo.momz*P_MobjFlip(mo) < 0 then 
			mo.state = S_PLAY_ROLL
			player.pflags = $&~(PF_THOKKED)
			player.actionstate = 0
		end
		if P_IsObjectOnGround(mo) then
			player.actionstate = 0
		end
	end

	//Spin Wave state
	if player.actionstate == state_superspinwave 
		B.ControlThrust(mo,FRACUNIT,nil,jumpfriction,nil)
					
		//Go into fall frames after end-rising
		if mo.momz*P_MobjFlip(mo) < 0 then 
			mo.state = S_PLAY_FALL
			player.pflags = $&~(PF_JUMPED)
			player.lockmove = false
			player.actionstate = 0
		end
		if P_IsObjectOnGround(mo) then
			B.ApplyCooldown(player,cooldown3)
			player.lockmove = false
			player.actionstate = 0
		end
	end

	//vfx
	if player.actionstate and player.pflags&PF_JUMPED then
		local zheight
		if (mo.eflags & MFE_VERTICALFLIP)
			zheight = mo.z + mo.height + FixedDiv(P_GetPlayerHeight(player) - mo.height, 3*FRACUNIT) - FixedMul(mobjinfo[MT_THOK].height, mo.scale)
		else
			zheight = mo.z - FixedDiv(P_GetPlayerHeight(player) - mo.height, 3*FRACUNIT)
		end
		
		if (not (mo.eflags & MFE_VERTICALFLIP)
		and (zheight < mo.floorz)
		and not (mobjinfo[MT_THOK].flags & MF_NOCLIPHEIGHT))
			zheight = mo.floorz
		elseif (mo.eflags & MFE_VERTICALFLIP and zheight + FixedMul(mobjinfo[MT_THOK].height, mo.scale) > mo.ceilingz and not (mobjinfo[MT_THOK].flags & MF_NOCLIPHEIGHT))
			zheight = mo.ceilingz - FixedMul(mobjinfo[MT_THOK].height, mo.scale)
		end
		
		local trail = P_SpawnGhostMobj(mo)
		P_MoveOrigin(trail, trail.x, trail.y, zheight)
		trail.fuse = 30
		trail.state = S_THOK
		trail.frame = TR_TRANS70|A
		trail.destscale = 0
		trail.spritexscale = mo.spritexscale
		trail.spriteyscale = mo.spriteyscale
		
		player.pflags = $|PF_THOKKED
	end
end
