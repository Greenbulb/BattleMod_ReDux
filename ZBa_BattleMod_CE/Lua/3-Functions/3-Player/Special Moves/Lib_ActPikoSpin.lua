local B = CBW_Battle

local specialstate = 1
local cooldown = TICRATE*2
local specialtime = 20
local specialendtime = 24
local thrust = FRACUNIT*2
local friction = FRACUNIT*10/10
local zfriction = FRACUNIT*9/10
local limit = FRACUNIT*36

local function ZLaunch(mo,thrust,relative)
	if mo.eflags&MFE_UNDERWATER
		thrust = $*3/5
	end
	P_SetObjectMomZ(mo,thrust,relative)
end

B.Action.PikoSpin_Priority = function(player)
	if player.actionstate == specialstate
		B.SetPriority(player,2,3,nil,2,3,"piko spin technique")
	end
end

local function sparkle(mo)
	local spark = P_SpawnMobj(mo.x,mo.y,mo.z,MT_SPARK)
	if spark and spark.valid then
		B.AngleTeleport(spark,{mo.x,mo.y,mo.z},mo.player.drawangle,0,mo.scale*64)
	end
end

local function spinhammer(mo)
	mo.state = S_PLAY_MELEE_LANDING
	mo.frame = 0
	//mo.player.pflags = ($ | PF_JUMPED | PF_THOKKED) & ~PF_NOJUMPDAMAGE
	mo.sprite2 = SPR2_MLEL
end

local DoThrust = function(mo)
	P_Thrust(mo,mo.angle,thrust)
	B.ControlThrust(mo,friction,limit,zfriction,nil)
	if not P_IsObjectOnGround(mo)
		B.ZLaunch(mo, FRACUNIT/3, true)
	end
end

local meme = function(mo,player)
	if not(player.dustdevil and player.dustdevil.valid)
		local missile = P_SPMAngle(mo,MT_DUSTDEVIL_BASE,mo.angle)
		if missile and missile.valid then
			missile.color = player.skincolor
			if not(player.mo.flags2&MF2_TWOD or twodlevel) then
				missile.fuse = TICRATE*5
			else
				missile.fuse = 45
			end
			S_StartSound(missile,sfx_s3kb8)
			S_StartSound(missile,sfx_s3kcfl)	

			if G_GametypeHasTeams() then
				missile.color = mo.color
			end
-- 				if P_MobjFlip(mo) == -1 then
-- 					missile.z = $-missile.height
-- 					missile.flags2 = $|MF2_OBJECTFLIP
-- 					missile.eflags = $|MFE_VERTICALFLIP
-- 				end
			if missile.tracer and missile.tracer.valid then
				missile.tracer.target = player.mo
				if P_MobjFlip(mo) == -1 then 
					missile.tracer.z = $-missile.tracer.height
					missile.tracer.flags2 = $|MF2_OBJECTFLIP
					missile.tracer.eflags = $|MFE_VERTICALFLIP
				end					
			end
			player.dustdevil = missile
		end
	end
end

B.Action.PikoSpin = function(mo,doaction)
	local player = mo.player
	if P_PlayerInPain(player) then
		player.actionstate = 0
		player.actiontime = 0
	end
	if not(B.CanDoAction(player)) and not(player.actionstate) 
		if player.actiontime and mo.state == S_PLAY_MELEE_FINISH
			if mo.tics == -1
				mo.tics = 15
			else
				mo.tics = min($,15)
			end
			player.actiontime = 0
		end
		return
	end
	player.actiontime = $+1
	//Action Info
	player.actiontext = "Piko Spin"
	player.actionrings = 10
	
	//Neutral
	if player.actionstate == 0
		//Trigger
		if (doaction == 1) then
			B.PayRings(player)
			B.ApplyCooldown(player,cooldown)
			player.actionstate = specialstate
			player.actiontime = 0
			mo.momz = $ / 2
			DoThrust(mo)
			S_StartSoundAtVolume(mo,sfx_3db16,130)
			S_StartSound(mo,sfx_s3ka0)
		end
	
	//Special
	elseif player.actionstate == specialstate then
		player.charability2 = CA2_MELEE
		player.powers[pw_nocontrol] = max($,2)
		sparkle(mo)
		player.drawangle = player.cmd.angleturn<<FRACBITS+ANGLE_45*(player.actiontime&7)
		DoThrust(mo)
		if player.actiontime&7 == 4 then
			S_StartSound(mo,sfx_s3k42)
		end
		if not(player.actiontime > specialtime)
			spinhammer(mo)
			return
		end
		player.actionstate = $ + 1
		player.actiontime = 0
		player.drawangle = mo.angle
		ZLaunch(mo, FRACUNIT*3, true)
		mo.momx = $ * 2/3
		mo.momy = $ * 2/3
		player.melee_state = st_release
		mo.state = S_PLAY_MELEE
		S_StartSound(mo,sfx_s3k52)
	
	//End lag
	elseif player.actionstate == specialstate+1 
		player.powers[pw_nocontrol] = max($,2)
		if player.actiontime >= specialendtime
			mo.state = S_PLAY_FALL
			player.actionstate = 0
			player.actiontime = 0
			meme(mo,player)
			return
		end
		if P_IsObjectOnGround(mo)
			player.actionstate = 0
			player.actiontime = 0
			meme(mo,player)
			return
		end
	end
end