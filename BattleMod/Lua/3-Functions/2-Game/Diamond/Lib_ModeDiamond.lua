 -- Diamond rework code by 'ket'
local B = CBW_Battle
local D = B.Diamond
local CV = B.Console
local CP = B.ControlPoint
D.Diamond = nil
D.LastDiamondPointNum = 0
D.Spawns = {}
D.DiamondIndicator = nil

-- for the capture points and stuff
D.CapturePoints = {}
D.ActivePoint = nil
D.Active = false
D.SpawnGrace = 0
D.PointUnlockTime = 0
D.CurrentPointNum = 0
D.LastPointNum = 0

local diamondtext = "\x87".."Warp Topaz".."\x80"
local rotatespd = ANG20

local function Wrap(num,size)
	if num > size then
		num = $-size
	end
	return num
end

D.GameControl = function()
	if not(B.DiamondGametype())or not(#D.Spawns) or B.PreRoundWait() 
	then return end

	if D.Diamond == nil or not(D.Diamond.valid) then
		if not(D.SpawnGrace) then
			D.SpawnGrace = CV.DiamondSpawnDelay.value
			for p in players.iterate do
				p.gotcrystal = false
				p.gotcrystal_time = 0
			end
		elseif leveltime % 2 == 0 then
			D.SpawnGrace = max(0,$-1)
			if not(D.SpawnGrace) then
				D.SpawnDiamond()
			end
		end
	end
	if D.DiamondIndicator == nil then
		D.DiamondIndicator = P_SpawnMobj(0, 0, 0, MT_GOTDIAMOND)
		D.DiamondIndicator.fuse = -1
		D.DiamondIndicator.flags2 = $|MF2_DONTDRAW
	end
end


D.Reset = function()
	--if not(B.DiamondGametype()) then return end
	D.Diamond = nil
	D.Spawns = {}
	D.CapturePoints = {}
	D.ActivePoint = nil
	D.DiamondIndicator = nil
	B.DebugPrint("Diamond mode reset",DF_GAMETYPE)
end

D.GenerateSpawns = function()
	if not(B.DiamondGametype()) then return end
	D.SpawnGrace = 0
	for thing in mapthings.iterate
		local t = thing.type
		if t == 3630 --Diamond Spawn object
			D.Spawns[#D.Spawns+1] = thing
			--D.CapturePoints[#D.CapturePoints+1] = P_SpawnMobj(x, y, z, MT_CONTROLPOINT)
			B.DebugPrint("Added Diamond spawn #"..#D.Spawns.. " from mapthing type "..t,DF_GAMETYPE)
		end
	end
	if not(#D.Spawns)
		B.DebugPrint("No diamond spawn points found on map. Checking for backup spawn positions...",DF_GAMETYPE)
		for thing in mapthings.iterate
			local t = thing.type
			if t == 1 --Player 1 Spawn
			or (t >= 330 and t <= 335) --Weapon Ring Panels
			or (t == 303) --Infinity Ring
			or (t == 3640) --Control Point
			or (t == 310) -- Red Flag
			or (t == 311) -- Blue Flag
				D.Spawns[#D.Spawns+1] = thing
				--D.CapturePoints[#D.CapturePoints+1] = P_SpawnMobj(thing.x*FRACUNIT, thing.y*FRACUNIT, thing.z*FRACUNIT, MT_CONTROLPOINT)
				B.DebugPrint("Added Diamond spawn #"..#D.Spawns.. " from mapthing type "..t,DF_GAMETYPE)
			end
		end
	end
	D.SpawnCapturePoints()
end

local function free(mo)
	mo.fuse = TICRATE
	mo.flags = $&~MF_SPECIAL
	mo.idle = TICRATE*16
end

D.SpawnCapturePoints = function()
	if not(B.DiamondGametype()) then return end
	for i = 1, #D.Spawns do
		local s = D.Spawns[i]
		if s == nil then continue end
		local fu = FRACUNIT
		local x = s.x*fu
		local y = s.y*fu
		local z = s.z*fu
		local subsector = R_PointInSubsector(x,y)
		if subsector.valid and subsector.sector then
			z = $+subsector.sector.floorheight
			D.CapturePoints[i] = P_SpawnMobj(x, y, z, MT_CONTROLPOINT)
		end
	end
end

D.SpawnDiamond = function()
	B.DebugPrint("Attempting to spawn topaz",DF_GAMETYPE)
	local num = P_RandomRange(1, #D.Spawns)
	if #D.Spawns > 2 then
		while num == D.LastDiamondPointNum or num == D.LastPointNum do
			num = $ + 1
			Wrap(num, #D.Spawns)
		end
	end

	local s = D.Spawns[num]
	if not s or not s.valid then return end
	local fu = FRACUNIT
	local x = s.x*fu
	local y = s.y*fu
	local z = s.z*fu
	local subsector = R_PointInSubsector(x,y)
	if subsector.valid and subsector.sector then
		z = $+subsector.sector.ceilingheight
		D.Diamond = P_SpawnMobj(x,y,z,MT_DIAMOND)
		D.ActivatePoint(num)
		D.LastDiamondPointNum = num
		B.DebugPrint("Topaz coordinates: "..D.Diamond.x/fu..","..D.Diamond.y/fu..","..D.Diamond.z/fu,DF_GAMETYPE)
		print("The "..diamondtext.." has been spawned!")
	end
end

D.ActivatePoint = function(num)
	D.PointUnlockTime = CV.DiamondPointUnlockTime.value
	local diamond = D.Diamond
	local dist = 0
	local pointnum = P_RandomRange(1, #D.Spawns)
	
	-- We use this because if a map only has two or less spawn points, we will get stuck in an infinite loop
	-- Not a perfect solution, but if your map has only 1 spawn point, consider it unplayable anyway...
	-- So in the meantime, let's skip the checks so that we don't crash if we end up on the wrong map
	local num_spawns = #D.Spawns

	if num_spawns > 3 then
		while (pointnum == num or pointnum == D.LastPointNum) do
			pointnum = $ + 1
			pointnum = Wrap(pointnum, num_spawns)
		end
	end
	
	D.ActivePoint = D.CapturePoints[pointnum]
	D.CurrentPointNum = pointnum
	D.LastPointNum = pointnum
	--B.DebugPrint("Capture Point with ID of: "..D.CurrentPointNum.." spawned at position: "..active_point.x..", "..active_point.y..", "..active_point.z)
end

local function play_steal_sounds(splayer, teamsound, otherteamsound, play_for_spectators, play_for_splayer)
	if play_for_spectators == nil then
		play_for_spectators = false
	end
	local has_teams = G_GametypeHasTeams()
	for player in players.iterate() do
		--if player == splayer and not play_for_splayer then
			----S_StartSoundAtVolume(nil, teamsound, 220, player)
			--continue
		--end
		if (has_teams and (player.ctfteam == splayer.ctfteam or (player.spectator and play_for_spectators == true)))
		or (not has_teams and (player == splayer) or (player.spector and play_for_spectators == true))
		then 
			S_StartSoundAtVolume(nil, teamsound, 125, player)
		else
			S_StartSoundAtVolume(nil, otherteamsound, 125, player)
		end
	end
end

local function play_for_all_but_players(sound1, sound2, splayer, sf_player)
	for player in players.iterate() do
		if player == splayer then continue end
		if G_GametypeHasTeams() and player.ctfteam == splayer then continue end
		S_StartSound(nil, sound, player)
	end
end

local function spawn_steal_sparks(mo, player, scale, speed, height, spawn_explosion)
	if spawn_explosion == nil then
		spawn_explosion = true
	end
	if scale == nil then
		scale = player.mo.scale
	end
	if speed == nil then
		speed = 10
	end

	if spawn_explosion then
		local s = P_SpawnMobjFromMobj(mo, 0, 0, 0, MT_BATTLESHIELD)
		s.scale = scale*3
	end

	for n = 0, 7 do
		--local p = P_SPMAngle(mo,MT_SUPERSPARK,mo.angle+n*ANGLE_45,0)
		local p = P_SpawnMobjFromMobj(mo, 0, 0, 0, MT_SUPERSPARK)
		if height ~= nil then
			p.z = height
		end
		P_InstaThrust(p, mo.angle+(n*ANGLE_45), speed*scale)
		if p and p.valid then
			--p.momz = mo.scale*P_MobjFlip(mo)*blastspeed/water
			p.fuse = 20
			p.scale = 5*scale/4
-- 						P_InstaThrust(p,p.angle,player.actiontime>>1)
		end
	end
end

D.Collect = function(mo,toucher)
	if mo.target == toucher or not(toucher.player) then return end --This toucher has already collected the item, or is not a player
	if P_PlayerInPain(toucher.player) or toucher.player.powers[pw_flashing] then return end --Can't touch if we've recently taken damage
	if toucher.player.tossdelay then return end --Can't collect if tossflag is on cooldown
	local previoustarget = mo.target
	mo.lasttouched = previoustarget or toucher
	if CV.DiamondDisableStealing.value == 1 and previoustarget ~= nil then return end
	if previoustarget ~= nil and previoustarget.player.powers[pw_flashing] > 0 then return end
	--if previoustarget ~= nil and (previoustarget.player.guard == 1 or previoustarget.player.guardtics > 0) then return end

	mo.target = toucher
	free(mo)
	mo.idle = nil
	S_StartSound(mo,sfx_lvpass)
	if not(previoustarget) then
		B.PrintGameFeed(toucher.player," picked up the "..diamondtext.."!")
		--S_StartSound(nil, sfx_dmstl1)
		play_steal_sounds(toucher.player, sfx_dmstl1, sfx_dmstl2, true)
		S_StartSoundAtVolume(nil, sfx_stlt, 150, toucher.player)
		spawn_steal_sparks(mo, toucher.player)
	else
		for player in players.iterate() do
			if player == toucher.player or player == previoustarget.player then
				S_StartSoundAtVolume(nil, sfx_dmstl3, 125, player)
			end

			if player == toucher.player then
				S_StartSoundAtVolume(nil, sfx_stlt, 125, toucher.player)
			elseif player == previoustarget.player then
				S_StartSoundAtVolume(nil, sfx_stle, 100, previoustarget.player)
			elseif G_GametypeHasTeams() then
				if player.ctfteam == toucher.player.ctfteam then
					S_StartSound(nil, sfx_dmstl1, player)
				elseif player.ctfteam == previoustarget.player.ctfteam then
					S_StartSound(nil, sfx_dmstl2, player)
				end
			elseif not G_GametypeHasTeams() then
				S_StartSound(nil, sfx_dmstl2, player)
			end
		end

		--S_StartSoundAtVolume(nil, sfx_dmstl3, 255, previoustarget.player)
		--play_steal_sounds(toucher.player, sfx_dmstl1, sfx_dmstl2, true)
		spawn_steal_sparks(mo, toucher.player)
		--if G_GametypeHasTeams() then
			--play_sound_for_team(sfx_dmstl1, mo.target.player.ctfteam)
			--play_sound_for_team(sfx_dmstl2, previoustarget.player.ctfteam)
		--else
			--S_StartSound(nil, sfx_dmstl1, mo.target.player)
			--play_for_all_but_player(sfx_dmstl2, mo.target.player)
		--end
		B.PrintGameFeed(toucher.player," stole the "..diamondtext.." from ",previoustarget.player,"!")
	end
end


D.Thinker = function(mo)
	mo.shadowscale = FRACUNIT>>2


	//Determine toss blink
	local tossblink = 0
	if mo.lasttouched and mo.lasttouched.player then
		tossblink = mo.lasttouched.player.tossdelay
	end

	if tossblink then
		
		local floorz = ((mo.flags2 & MF2_OBJECTFLIP) and mo.ceilingz-(FRACUNIT/2)) or mo.floorz+(FRACUNIT/2)

		if not(mo.floorvfx and (type(mo.floorvfx) == "table")) then
			mo.floorvfx = {}
		end

		local color = ((tossblink > (TICRATE/4)) and (mo.lasttouched.player.skincolor)) or (pcall(do return skincolors[mo.lasttouched.player.skincolor].invcolor end) and skincolors[mo.lasttouched.player.skincolor].invcolor) or ((mo.lasttouched.player.skincolor == SKINCOLOR_GOLD) and SKINCOLOR_AQUAMARINE) or SKINCOLOR_GOLD
		local blendmode = ((tossblink > (TICRATE/4)) and AST_TRANSLUCENT) or AST_ADD

		if #mo.floorvfx < 6 then
			table.insert(mo.floorvfx, P_SpawnMobj(mo.x, mo.y, floorz, MT_GHOST_VFX))
			local vfx = mo.floorvfx[#mo.floorvfx]
			if (mo.flags2 & MF2_OBJECTFLIP) then
				vfx.flags2 = $|MF2_OBJECTFLIP
			end
			vfx.fuse = mobjinfo[MT_GHOST].damage/2
			vfx.renderflags = $|RF_FULLBRIGHT|RF_FLOORSPRITE|RF_ABSOLUTEOFFSETS|RF_NOCOLORMAPS
			vfx.spritexoffset = 45*FRACUNIT
			vfx.spriteyoffset = 45*FRACUNIT
			vfx.blendmode = blendmode
			vfx.sprite = SPR_STAB
			vfx.destscale = mo.scale*2
			vfx.frame = 0|FF_TRANS50
			vfx.colorized = true
			vfx.color = color
			vfx.flags2 = $|MF2_SPLAT
		end
		for k, vfx in ipairs(mo.floorvfx) do
			if not(vfx and vfx.valid) then
				table.remove(mo.floorvfx, k)
			else
				vfx.color = color
			end
		end
	else
		if mo.floorvfx and (type(mo.floorvfx) == "table") then
			--print("exists")
			for k, vfx in ipairs(mo.floorvfx) do
				if vfx and vfx.valid then
					--print("deleted")
					P_RemoveMobj(vfx)
				end
				table.remove(mo.floorvfx, k)
				--print("removed")
			end
			mo.floorvfx = nil
		end
	end


	--Idle timer
	if mo.idle != nil then 
		mo.idle = $-1
		if mo.idle == 0
			P_SpawnMobj(mo.x,mo.y,mo.z,MT_SPARK)
			P_RemoveMobj(mo)
		return end
	end
	--Blink
	if mo.fuse&1
		mo.flags2 = $|MF2_DONTDRAW
	else
		mo.flags2 = $&~MF2_DONTDRAW
	end
	if mo.target then 
		mo.destscale = FRACUNIT
	else
		mo.destscale = FRACUNIT*2
	end
	
	--Sparkle
	if not(leveltime&3) then
		local i = P_SpawnMobj(mo.x,mo.y,mo.z-mo.height/4,MT_IVSP)
-- 		i.flags2 = $|MF2_SHADOW
		i.scale = mo.scale
		i.color = B.FlashRainbow(mo)
		i.colorized = true
		local g = B.SpawnGhostForMobj(mo)
		g.color = B.FlashRainbow(mo)
		g.colorized = true
	end
	--Color
	mo.colorized = true	
	if not(mo.target) then
		--mo.color = B.FlashColor(SKINCOLOR_SUPERSILVER1,SKINCOLOR_SUPERSILVER5)
		mo.color = B.FlashRainbow(mo)
	else
		mo.color = mo.target.player.skincolor
	end
	mo.frame = $|FF_FULLBRIGHT
	mo.angle = $+rotatespd
	for player in players.iterate
		if not player.mo then continue end
		if D.Diamond and D.Diamond.valid and not(player.mo.btagpointer) then
			player.mo.btagpointer = P_SpawnMobjFromMobj(player.mo, 0, 0, 0, MT_BTAG_POINTER)
			if player.mo.btagpointer and player.mo.btagpointer.valid then
				player.mo.btagpointer.tracer = player.mo
				player.mo.btagpointer.target = D.Diamond
			end
		end
		if player.mo == mo.target then
			if player.cmd.buttons&BT_TOSSFLAG and not(player.tossdelay) then
				free(mo)
				mo.target = nil
				player.actioncooldown = TICRATE
				player.gotcrystal = false
				player.gotcrystal_time = 0
				P_MoveOrigin(mo,player.mo.x,player.mo.y,player.mo.z)
				P_InstaThrust(mo,player.mo.angle,FRACUNIT*5)
				P_SetObjectMomZ(mo,FRACUNIT*10)
				player.tossdelay = TICRATE*2
			else
				player.gotcrystal = true
				--points(player)
				--player.gotcrystal_time = $ + 1
				-- Add capture point code here..?
			end
		else
			player.gotcrystal = false
			player.gotcrystal_time = 0
		end
	end
	--Owner has been pushed by another player
	if mo.flags&MF_SPECIAL and mo.target and mo.target.valid 
	and mo.target.pushed_last and mo.target.pushed_last.valid
	and CV.DiamondDisableStealing.value == 0 then
		D.Collect(mo,mo.target.pushed_last)
	end
	
	--Owner has taken damage or has gone missing
	if mo.target then
		if not(mo.target.valid)
		or P_PlayerInPain(mo.target.player)
		or mo.target.player.playerstate != PST_LIVE
		or mo.target.player.tossdelay then
			if mo.target and mo.target.valid and mo.target.player then
				B.PrintGameFeed(mo.target.player," dropped the "..diamondtext..".")
			end
			mo.target.player.captures = 0
			mo.target = nil
			P_SetObjectMomZ(mo,FRACUNIT*10)
			P_InstaThrust(mo,mo.angle,FRACUNIT*5)	
			free(mo)
		end
	end
	
	--Unclaimed behavior
	if not(mo.target and mo.target.player) then
		mo.flags = ($|MF_BOUNCE)&~(MF_SLIDEME|MF_NOGRAVITY)
		if mo.z < mo.floorz+mo.scale*12 then
			mo.momz = $+mo.scale
		end
		return
	end
	
	--Claimed behavior
	mo.flags = ($&~MF_BOUNCE)|MF_NOGRAVITY|MF_SLIDEME
	local t = mo.target
	local ang = mo.angle + t.angle
	local dist = mo.target.radius*3
	local x = t.x+P_ReturnThrustX(mo,ang,dist)
	local y = t.y+P_ReturnThrustY(mo,ang,dist)
	local z = t.z+abs(leveltime&63-31)*FRACUNIT/2 --Gives us a hovering effect
	if P_MobjFlip(t) == 1 then --Make sure our vertical orientation is correct
		t.flags2 = $&~MF2_OBJECTFLIP
	else
		z = $+t.height
		t.flags2 = $|MF2_OBJECTFLIP
	end
	P_MoveOrigin(mo,t.x,t.y,t.z)
	P_InstaThrust(mo,R_PointToAngle2(mo.x,mo.y,x,y),min(FRACUNIT*60,R_PointToDist2(mo.x,mo.y,x,y)))
	mo.z = max(mo.floorz,min(mo.ceilingz+mo.height,z)) --Do z pos while respecting level geometry
end

D.CapturePointThinker = function(mo)
	if not (B.DiamondGametype())then return end
	local radius
	local height
	local meter
	if CV.DiamondPointRadius.value > 0 then --Calculate radius
		radius = CP.CalcRadius(CV.DiamondPointRadius.value)
	else
		radius = mo.cp_radius
	end
	if CV.CPHeight.value > 0 then --Calculate height
		height = CP.CalcHeight(CV.CPHeight.value)
	elseif CV.CPHeight.value == -1 then
		height = mo.ceilingz - mo.floorz
	elseif mo.cp_height > 0 then
		height = mo.cp_height
	else
		height = mo.ceilingz - mo.floorz
	end

	--Get Orientation and surfaces
	local flip = P_MobjFlip(mo)
	local floor
	local ceil
	if flip == 1 then
		floor = mo.floorz
		ceil = mo.ceilingz
	else
		floor = mo.ceilingz
		ceil = mo.floorz
	end

	CP.PointHover(mo,floor,flip,height)
	-- this executes for every control point on the map
	if mo == D.ActivePoint then
		D.CapturePointActiveThinker(mo, floor, flip, ceil, radius, height)
	else
		CP.InertThinker(mo)
	end
end

local textmapToEsc = {
	[0] = "\x80",
	[V_MAGENTAMAP] = "\x81",
	[V_YELLOWMAP] = "\x82",
	[V_GREENMAP] = "\x83",
	[V_BLUEMAP] = "\x84",
	[V_REDMAP] = "\x85",
	[V_GRAYMAP] = "\x86",
	[V_ORANGEMAP] = "\x87",
	[V_SKYMAP] = "\x88",
	[V_PURPLEMAP] = "\x89",
	[V_AQUAMAP] = "\x8A",
	[V_PERIDOTMAP] = "\x8B",
	[V_AZUREMAP] = "\x8C",
	[V_BROWNMAP] = "\x8D",
	[V_ROSYMAP] = "\x8E",
	[V_INVERTMAP] ="\x8F"
}

D.CapturePointActiveThinker = function(mo,floor,flip,ceil,radius,height)	
	mo.flags2 = $&~MF2_SHADOW
	local function randomcolor() 
		if D.PointUnlockTime <= 0 then
			return P_RandomRange(1,113) 
		else
			return SKINCOLOR_JET
		end
	end
	
	local function visual_cp(mo,floor,radius,fuse,quadrants,color)
		for n = 1,8
			local t
			local item = MT_CPBONUS
			if n == 1 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle,radius),mo.y+P_ReturnThrustY(mo,mo.angle,radius),floor,item)
			elseif n == 2 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_90,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_90,radius),floor,item)
			elseif n == 3 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_180,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_180,radius),floor,item)
			elseif n == 4 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_270,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_270,radius),floor,item)
			elseif n == 5 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_45,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_45,radius),floor,item)
			elseif n == 6 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_135,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_135,radius),floor,item)
			elseif n == 7 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_225,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_225,radius),floor,item)
			elseif n == 8 then t = P_SpawnMobj(mo.x+P_ReturnThrustX(mo,mo.angle+ANGLE_315,radius),mo.y+P_ReturnThrustY(mo,mo.angle+ANGLE_315,radius),floor,item)
			end
			if t and t.valid then
				t.color = color
				t.fuse = fuse
				t.extravalue1 = t.fuse
				if flip == -1 then t.flags2 = $|MF2_OBJECTFLIP end
			end
			if quadrants and n >= 4 then break end
		end
	end
	
	--Visuals
	mo.angle = $+ANG1*3
	visual_cp(mo,floor,radius,16,false,randomcolor())
	visual_cp(mo,floor,radius,16,false,randomcolor())
	visual_cp(mo,floor+flip*height/4,radius/8,2,true,mo.color)
	visual_cp(mo,floor+flip*height/8,radius/16,2,true,mo.color)
	visual_cp(mo,flip*height+floor,radius,16,false,randomcolor())
	visual_cp(mo,flip*height*3/4+floor,radius/8,2,true,mo.color)
	visual_cp(mo,flip*height*7/8+floor,radius/16,2,true,mo.color)
	mo.color = SKINCOLOR_GREY

	if D.PointUnlockTime > 0 then 
		D.PointUnlockTime = $ - 1 
		-- play countdown sfx
		if (D.PointUnlockTime == TICRATE or D.PointUnlockTime == TICRATE*2 or D.PointUnlockTime == TICRATE*3) then
			S_StartSound(nil,sfx_s3ka7)
		end
		return 
	elseif D.PointUnlockTime == 0 then
		-- let us know the point is unlocked
		S_StartSound(nil, sfx_prloop)
		print("A\x82 Capture Zone\x80 has been unlocked!")
		D.PointUnlockTime = -1 -- so that we only do this once, we set unlocktime to -1
	end

	mo.color = SKINCOLOR_YELLOW

	local diamond = D.Diamond
	if not diamond or not diamond.valid then return end
	if not diamond.target or not diamond.target.valid then return end
	local player = diamond.target.player

	-- if the diamond exists, make the control point the color of the diamond, just for the fun of it.
	mo.color = diamond.color


	local function tumble_players_in_point(splayer)
		if CV.DiamondTumbleAfterCap.value == 0 then return end
		local pdist = 0
		for p in players.iterate() do
			if p.spectator or not p.mo or not p.mo.valid then continue end
			if G_GametypeHasTeams() and p.ctfteam == splayer.ctfteam then continue end
			if p == splayer then continue end

			pdist = R_PointToDist2(p.mo.x, p.mo.y, mo.x, mo.y)
			B.DoPlayerTumble(p, TICRATE*2, 0, 8*p.mo.scale, true)
		end
	end

	local dist = R_PointToDist2(mo.x, mo.y, player.mo.x, player.mo.y)
	local zdiff = abs(mo.floorz - player.mo.floorz)
	local same_height_as_point = (player.mo.floorz >= mo.floorz and player.mo.floorz < mo.floorz + height) 
	or (P_MobjFlip(mo) == -1 and player.mo.floorz <= mo.floorz and player.mo.floorz > (mo.floorz - height)
	or player.mo.floorz <= mo.floorz and player.mo.floorz >= mo.floorz - 5*player.mo.scale)

	if dist <= radius 
	and (same_height_as_point)
	and (P_IsObjectOnGround(player.mo) or P_IsObjectInGoop(player.mo))
	then
		S_StartSound(nil, sfx_prloop)
		tumble_players_in_point(player)
		spawn_steal_sparks(mo, player, mo.scale*3, 35, mo.floorz, false)

		local teamscoreincrease = 0
		local scoreincrease = 0
		for p in players.iterate()
			if splitscreen and p == players[1] then 
				return
			end
			S_StartSound(nil, sfx_s243, p)
			local sfx
			local lose
			if G_GametypeHasTeams() then
				if (p.ctfteam == player.ctfteam) or p.spectator or splitscreen then
					sfx = sfx_s3k68
				else
					sfx = sfx_lose
					lose = true
				end
			else
				if (p == player) then
					sfx = sfx_s3k68
				else
					sfx = sfx_lose
					lose = true
				end
			end
			S_StartSoundAtVolume(nil, B.ShortSound(player, sfx, lose), (B.ShortSound(player, nil, nil, nil, true)).volume or 255, p)
		end
		local playertextmap = (pcall(do return skincolors[player.skincolor].chatcolor end) and skincolors[player.skincolor].chatcolor) or 0
		local playerEsc = (rawget(textmapToEsc, playertextmap) and textmapToEsc[playertextmap]) or "\x80"
		local teamEsc = ((player.ctfteam == 1) and "\x85") or ((player.ctfteam == 2) and "\x84")
		if (not(G_GametypeHasTeams()) and CV.DiamondCapsBeforeReset.value == 1)
		or (G_GametypeHasTeams() and CV.DiamondTeamCapsBeforeReset.value == 1)
		then
			P_RemoveMobj(diamond)
			S_StartSound(nil, sfx_s3kb3)
			scoreincrease = CV.DiamondCaptureBonus.value
			teamscoreincrease = 1
			print(player.name.." captured the "..diamondtext.."!")--Not sure how to color this text...
			B.DoFirework(player.mo)

			--Reuse CTF's capture HUD
			
			B.CTF.GameState.CaptureHUDTimer = 2*TICRATE
			B.CTF.GameState.CaptureHUDName = (teamEsc or playerEsc)..player.name.."\x80"
			B.CTF.GameState.CaptureHUDTeam = 0 --For now...
		else
			if player.captures == nil then
				player.captures = 0
			end

			if ((not G_GametypeHasTeams()) and CV.DiamondCapsBeforeReset.value == 0 and player.captures == 0)
			or (G_GametypeHasTeams() and CV.DiamondTeamCapsBeforeReset.value == 0 and player.captures == 0)
			then
				player.captures = D.ActivePointNum
			elseif ((not G_GametypeHasTeams()) and CV.DiamondCapsBeforeReset.value ~= 0)
			or (G_GametypeHasTeams() and CV.DiamondTeamCapsBeforeReset.value ~= 0) then
				player.captures = $ + 1
			end
			--print(player.captures)

			D.ActivePointNum = ($ + 1)
			if D.ActivePointNum > #D.PointSpawns then
				D.ActivePointNum = 1
			end
			--print("active_point: "..D.ActivePointNum)
			if ((not G_GametypeHasTeams()) and player.captures == CV.DiamondCapsBeforeReset.value and CV.DiamondCaptureResetAmount.value ~= 0) 
			or ((not G_GametypeHasTeams()) and D.ActivePointNum == player.captures and CV.DiamondCapsBeforeReset.value == 0) 
			or (G_GametypeHasTeams() and D.ActivePointNum == player.captures and CV.DiamondTeamCapsBeforeReset.value == 0)
			or (G_GametypeHasTeams() and player.captures == CV.DiamondTeamCapsBeforeReset.value and CV.DiamondTeamCapsBeforeReset.value ~= 0)
			then
				player.captures = 0
				player.score = $ + CV.DiamondCaptureBonus.value
				P_RemoveMobj(diamond)
				S_StartSound(nil, sfx_s3kb3)
				scoreincrease = (CV.DiamondCaptureBonus.value*2)
				teamscoreincrease = 2
				print(player.name.." just went full circle and got triple points!")
			else
				scoreincrease = CV.DiamondCaptureBonus.value
				teamscoreincrease = 1
				print(player.name.." just scored!")
			end
		end

		-- individual scoring
		P_AddPlayerScore(player, scoreincrease)
		-- team scoring
		if G_GametypeHasTeams() then
			if player.ctfteam == 1 then -- red team scoring
				redscore = $+teamscoreincrease
			elseif player.ctfteam == 2 then	-- blue team scoring
				bluescore = $+teamscoreincrease
			end
		end
		--COM_BufInsertText(server, "csay "..player.name.."\\captured the "..diamondtext.."!\\\\")--Not sure how to color this text...
	end
end

--D.DiamondIndicatorThinker = function()
	--if not B.DiamondGametype() then return end
	--if D.DiamondIndicator == nil then
		--D.DiamondIndicator = P_SpawnMobj(0, 0, 0, MT_GOTDIAMOND)
		--D.DiamondIndicator.fuse = -1
		--D.DiamondIndicator.flags2 = $|MF2_DONTDRAW
	--end
	--if CV.DiamondIndicator.value == 0 then 
		--D.DiamondIndicator.flags2 = $|MF2_DONTDRAW
		--return 
	--end

	--local diamond = D.Diamond
	--local mo = D.Diamond.target
	--if not mo then
		--D.DiamondIndicator.flags2 = $|MF2_DONTDRAW
		--return
	--end
	--local player = mo.player
	--local indicator = D.DiamondIndicator

	--if player == displayplayer then
		--indicator.flags2 = $|MF2_DONTDRAW
		--if leveltime % (TICRATE/2) == 0 then
			--S_StartSoundAtVolume(nil, sfx_s24d, 125, player)
		--end
		--if not S_IdPlaying(sfx_shimr) then
			--S_StartSoundAtVolume(nil, sfx_shimr, 125, player)
		--end
	--else
		--indicator.flags2 = $&~MF2_DONTDRAW
	--end
	--local z = mo.z + mo.height + 16*mo.scale
	--P_MoveOrigin(D.DiamondIndicator, mo.x, mo.y, z)
--end

D.DiamondIndicatorThinker = function()
	if not B.DiamondGametype() then return end
	if D.DiamondIndicator == nil then return end
	local indicator = D.DiamondIndicator

	local noplayershadcrystal = true
	for player in players.iterate() do
		if not player.gotcrystal then continue end
		local mo = player.mo
		local z = mo.z + mo.height + 16*mo.scale
		P_MoveOrigin(D.DiamondIndicator, mo.x, mo.y, z)

		if player == displayplayer then
			indicator.flags2 = $|MF2_DONTDRAW
			--[[
			if leveltime % (TICRATE/2) == 0 then
				S_StartSoundAtVolume(nil, sfx_s24d, 125, player)
			end
			]]
			if not S_IdPlaying(sfx_shimr) then
				S_StartSoundAtVolume(nil, sfx_shimr, 125, player)
			end
		else
			indicator.flags2 = $&~MF2_DONTDRAW
		end
		noplayershadcrystal = false

	end

	if noplayershadcrystal or CV.DiamondIndicator.value == 0 then
		indicator.flags2 = MF2_DONTDRAW
	end
end
