local B = CBW_Battle
local cooldown1 = TICRATE
local cooldown2 = TICRATE*2
local state_superspinjump = 1
local state_groundpound_rise = 2
local state_groundpound_fall = 3
local jumpthrust = 42*FRACUNIT
local pound_startthrust = 0
local pound_downaccel = FRACUNIT*4//4
local jumpfriction = FRACUNIT*9/10
local poundfriction = FRACUNIT
local reboundthrust = 10

B.Action.SuperSpinJump_Priority = function(player)
	if player.actionstate == state_superspinjump then
		B.SetPriority(player,2,2,nil,2,2,"super spin jump")
	elseif player.actionstate == state_groundpound_rise then
		B.SetPriority(player,1,2,nil,1,2,"rising ground pound")
	elseif player.actionstate == state_groundpound_fall then
		B.SetPriority(player,2,2,nil,2,2,"ground pound")
	end
end

B.Action.SuperSpinJump=function(mo,doaction)
	local player = mo.player
	if not(B.CanDoAction(player)) then
		player.actionstate = 0
	return end
	//Action info
	if P_IsObjectOnGround(mo) then
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
		if doaction == 1 then
			B.PayRings(player)
			//Do high jump
			if P_IsObjectOnGround(mo) then
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
				B.ApplyCooldown(player,cooldown1)
			else//Do ground pound
				B.ApplyCooldown(player,cooldown2)
				thrust = pound_startthrust/water
				player.actionstate = state_groundpound_rise
				P_SetObjectMomZ(mo,thrust,false)
				S_StartSound(mo,sfx_zoom)
				mo.state = S_PLAY_ROLL
				player.pflags = jumpflags
				player.secondjump = 0
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
		local endgroundpound = false
		if mo.momz*P_MobjFlip(mo) > 0 then //If we're moving upward, then something must have interrupted us.
			endgroundpound = true
		else
			P_SetObjectMomZ(mo,-pound_downaccel/water,true)
			if mo.eflags&MFE_JUSTHITFLOOR then //We have hit a surface
				endgroundpound = true
				thrust = reboundthrust*FRACUNIT/water
				P_SetObjectMomZ(mo,thrust,true) //Inherit platform momentum
				S_StartSound(mo,sfx_s3k5f)
				player.state = S_PLAY_SPRING
				P_InstaThrust(mo,R_PointToAngle2(0,0,mo.momx,mo.momy),FixedHypot(mo.momx,mo.momy)/2)
				//Create projectile blast
				for n = 0, 23
					local p = P_SPMAngle(mo,MT_GROUNDPOUND,mo.angle+n*ANG15,0)
					if p and p.valid then
						p.momz = mo.scale*P_MobjFlip(mo)*2/water
						p.fuse = TICRATE/3
-- 						P_InstaThrust(p,p.angle,player.actiontime>>1)
					end
				end
			else
				player.actiontime = abs(mo.momz)
			end
		end
		if endgroundpound //End ground pound state
			player.actionstate = 0
			mo.state = S_PLAY_SPRING
			if player.pflags&PF_JUMPED then
				player.pflags = $|PF_STARTJUMP|PF_NOJUMPDAMAGE
			end
			player.pflags = $&~PF_SPINNING
		end
	end
	//SuperSpinJump state
	if player.actionstate == state_superspinjump 
		B.ControlThrust(mo,FRACUNIT,nil,jumpfriction,nil)
		//Go into fall frames after end-rising
		if mo.momz*P_MobjFlip(mo) < 0 then 
			mo.state = S_PLAY_FALL
			player.pflags = $&~(PF_JUMPED)
			player.actionstate = 0
		end
		if P_IsObjectOnGround(mo) then
			player.actionstate = 0
		end
	end
	if player.actionstate and player.pflags&PF_JUMPED then
		P_SpawnThokMobj(player)
		player.pflags = $|PF_THOKKED
	end
end