local B = CBW_Battle
B.RedBank = nil
B.BlueBank = nil



local addPoints = function(team, points)
	if team == 1
		redscore = $ + points
	else
		bluescore = $ + points
	end
end

local bankTime = function(player)
	return max(1, 6 - ( FixedSqrt(player.rings * FRACUNIT / 2)>>FRACBITS ) )
end

local robTime = function(player)
	return min(15, FixedSqrt(player.rings * FRACUNIT)>>FRACBITS)
end

local bankTouch = function(mo, pmo)
	return gametype == GT_BANK or nil
end

local baseSparkle = function(player, team)
	local spark
	if team == 1 and B.RedBank and B.RedBank.valid
		spark = P_SpawnMobjFromMobj(B.RedBank, 0, 0, 0, MT_SPARK)
	elseif team == 2 and B.BlueBank and B.BlueBank.valid
		spark = P_SpawnMobjFromMobj(B.BlueBank, 0, 0, 0, MT_SPARK)
	end
	if spark and spark.valid
		spark.momx = P_RandomRange(-2, 2) * spark.scale
		spark.momy = P_RandomRange(-2, 2) * spark.scale
		spark.momz = P_RandomRange(1, 3) * spark.scale
		spark.color = player.ctfteam == 1 and SKINCOLOR_RED or SKINCOLOR_BLUE
		spark.colorized = true
		spark.flags = $|MF_NOCLIP|MF_NOCLIPHEIGHT
	end
end

local baseTransaction = function(player, team)
	if player.tossdelay or B.Exiting then
		return true
	end
	-- Get current team score
	local score
	if team == 1
		score = redscore
	else
		score = bluescore
	end
	if player.ctfteam == team
		-- Deposit rings
		if player.rings > 0 and P_IsObjectOnGround(player.mo) and not player.actionstate
			S_StartSound(player.mo, sfx_itemup)
			P_GivePlayerRings(player, -1)
			P_AddPlayerScore(player, 1)
			addPoints(team, 1)
			player.tossdelay = bankTime(player)
			local spark = P_SpawnMobjFromMobj(player.mo, 0, 0, 0, MT_BOXSPARKLE)
			if spark and spark.valid
				spark.colorized = true
				spark.color = SKINCOLOR_CARBON
			end
			baseSparkle(player, team)
		end
	else
		-- Steal rings
		if score > 0 and P_IsObjectOnGround(player.mo) and not player.actionstate
			S_StartSound(player.mo, sfx_itemup)
			P_AddPlayerScore(player, 1)
			P_GivePlayerRings(player, 1)
			addPoints(team, -1)
			player.tossdelay = robTime(player)
			P_SpawnMobjFromMobj(player.mo, 0, 0, 0, MT_SPARK)
			baseSparkle(player, team)
		end
	end
	return true
end

addHook('TouchSpecial', function(mo, pmo)
	return bankTouch(mo, pmo)
end, MT_REDFLAG)

addHook('TouchSpecial', function(mo, pmo)
	return bankTouch(mo, pmo)
end, MT_BLUEFLAG)

local spawnFunc = function(mo, team)
	if gametype != GT_BANK
		return
	end
	if team == 1
		B.RedBank = mo
		B.RedBank.chaosrings = 0
	else
		B.BlueBank = mo
		B.BlueBank.chaosrings = 0
	end
	mo.state = S_TEAMRING
	mo.scale = $<<1
	mo.flags = $|MF_NOGRAVITY
	mo.renderflags = $|RF_SEMIBRIGHT
end

addHook('MobjSpawn', function(mo)
	spawnFunc(mo, 1)
end, MT_REDFLAG)

addHook('MobjSpawn', function(mo)
	spawnFunc(mo, 2)
end, MT_BLUEFLAG)

local flashColor = function(colormin,colormax, rate)
	local N = rate or 32 //Rate of oscillation
-- 	local size = colormax-colormin+1 //Color spectrum
	local scale = 2 //Factor-amount to reduce the oscillation intensity
	local offset = 0 //Offset the origin of oscillation
	local oscillate = abs((leveltime&(N*2-1))-N)/scale //Oscillation cycle
	local c = colormin+oscillate+offset //offset
	c = max(colormin,min(colormax,$)) //Enforce min/max
	return c
end

local getBase = function(player)
	if not P_IsObjectOnGround(player.mo) then return end

	--// rev: credits to JAB, he figured this one out. This will work for both UDMF / Binary maps
	if P_MobjTouchingSectorSpecialFlag(player.mo, SSF_REDTEAMBASE) then
		return 1
	elseif P_MobjTouchingSectorSpecialFlag(player.mo, SSF_BLUETEAMBASE) then
		return 2
	else
		return 0
	end
end

local highValueSparkle = function(player)
	if leveltime % 2
		local w = player.mo.radius>>FRACBITS
		local h = player.mo.height>>FRACBITS
		local x = P_RandomRange(-w, w) * FRACUNIT
		local y = P_RandomRange(-w, w) * FRACUNIT
		local z = P_RandomRange(0, h) * FRACUNIT
-- 		local fx = P_SpawnMobjFromMobj(player.mo, x, y, z, MT_BOXSPARKLE)
		local fx = P_SpawnMobjFromMobj(player.mo, x, y, z, MT_BOXSPARKLE)
		if fx and fx.valid
			fx.scale = $>>1
			fx.fuse = P_RandomRange(10, 65)
			local spd = FixedMul(fx.scale, P_RandomRange(0, FRACUNIT-1))
			local angle = FixedAngle(P_RandomRange(0, 259)*FRACUNIT)
			P_Thrust(fx, angle, spd)
			P_SetObjectMomZ(fx, P_RandomRange(0, FRACUNIT-1), true)
-- 			if P_RandomChance(FRACUNIT>>2)
				fx.colorized = true
				fx.color = SKINCOLOR_GOLD
-- 			end
			if player == displayplayer
				fx.flags2 = $|MF2_SHADOW|FF_ADD
			end
		end
	end
end


mobjinfo[freeslot("MT_BATTLE_CHAOSRING")] = {
	doomednum = -1,
	spawnstate = S_TEAMRING,
	height = 32*FRACUNIT,
	radius = 16*FRACUNIT,
	flags = MF_SPECIAL|MF_NOGRAVITY
}

mobjinfo[freeslot("MT_BATTLE_CHAOSRINGSPAWNER")] = {
	doomednum = 3707,
	spawnstate = S_NULL
}

local addHudSparkle = function(team, direction)
	local w = 22
	local h = 14
	local x, y = 130 + P_RandomRange(0,w), 6
	local momy = 1
	if team == 1
		x = $ + 40
	end
	if direction == 1
		momy = -$
		y = $+h
	end
	table.insert(hudobjs, {
		drawtype = "sprite",
		string = "NSPK",
		frame = 1,
		flags = V_SNAPTOTOP|V_PERPLAYER,
		x = FRACUNIT * x,
		y = FRACUNIT * y,
		momy = momy * FRACUNIT,
		friction = FRACUNIT * 15 / 16,
		scale = FRACUNIT >> 2,
		fuse = 28
	})
end

--Constants
local CHAOSRING_STARTSPAWNBUFFER = TICRATE*2 --Time it takes for Chaos Rings to start spawning
local CHAOSRING_SPAWNBUFFER = TICRATE*46 --Chaos rings spawn every X seconds
local CHAOSRING_SCALE = FRACUNIT+(FRACUNIT/2)
local CHAOSRING_TYPE = MT_BATTLE_CHAOSRING
local CHAOSRING_WINTIMER = TICRATE*12
local CHAOSRING_CAPTIME = TICRATE*5
local CHAOSRING_INVULNTIME = TICRATE*15

local CHAOSRING1 = 1<<0
local CHAOSRING2 = 1<<1
local CHAOSRING3 = 1<<2
local CHAOSRING4 = 1<<3
local CHAOSRING5 = 1<<4
local CHAOSRING6 = 1<<5

local CHAOSRING_ENUM = {CHAOSRING1, CHAOSRING2, CHAOSRING3, CHAOSRING4, CHAOSRING5, CHAOSRING6}

local idletics = TICRATE*16
local waittics = TICRATE*4
local freetics = TICRATE
local bounceheight = 10
local rotatespd = ANG1*8

local SLOWCAPPINGALLY_SFX  = sfx_kc5a
local SLOWCAPPINGENEMY_SFX = sfx_kc59

local CHAOSRING_SPAWNTABLE = {}
local CHAOSRING_WINCOUNTDOWN = CHAOSRING_WINTIMER
local CHAOSRING_LIVETABLE = {nil, nil, nil, nil, nil, nil} --Table where you can get each Chaos ring's Object

local CHAOSRING_DATA = {
	[1] = { --Gold
		color = SKINCOLOR_GOLDENROD,
		textmap = "\x82"
	},

	[2] = { --Light Blue
		color = SKINCOLOR_SKY,
		textmap = "\x88"
	},

	[3] = { --Green
		color = SKINCOLOR_MASTER,
		textmap = "\x83"
	},

	[4] = { --Pink
		color = SKINCOLOR_FANCY,
		textmap = "\x81"
	},

	[5] = { --Purple
		color = SKINCOLOR_PURPLE,
		textmap = "\x89"
	},

	[6] = { --Blue
		color = SKINCOLOR_SAPPHIRE,
		textmap = "\x84"
	}
}
local CHAOSRING_TEXT = function(num)
	return CHAOSRING_DATA[num].textmap.."Chaos Ring".."\x80"
end

addHook('MapLoad', do

	if gametype ~= GT_BANK then return end
	CHAOSRING_SPAWNTABLE = {} --Clear the table

	for mt in mapthings.iterate do
		if mt and (mt.type == (mobjinfo[MT_BATTLE_CHAOSRINGSPAWNER].doomednum)) and mt.valid then --Match Chaos Emerald Spawn

			local chaosring_spawn = { --Data for the spawn
				x = mt.x*FRACUNIT,
				y = mt.y*FRACUNIT,
				z = mt.z*FRACUNIT,
				options = mt.options,
				mo = nil --Will use this field later
			}

			table.insert(CHAOSRING_SPAWNTABLE, chaosring_spawn)
			--print("Inserted chaosring_spawn #"..#CHAOSRING_SPAWNTABLE)
		end
	end
end)

local freetics = TICRATE
local idletics = TICRATE*16

local function free(mo)
	if not (mo and mo.valid) then return end
	mo.fuse = freetics
	mo.flags = ($|MF_GRENADEBOUNCE) & ~(MF_SPECIAL)
	mo.idle = idletics
end


local function touchChaosRing(mo, toucher) --Going to copy Ruby/Topaz code here
	if mo.target == toucher or not(toucher.player) -- This toucher has already collected the item, or is not a player
	or P_PlayerInPain(toucher.player) or toucher.player.powers[pw_flashing] -- Can't touch if we've recently taken damage
	or toucher.player.tossdelay -- Can't collect if tossflag is on cooldown
		return true
	end
	local previoustarget = mo.target
	if (G_GametypeHasTeams() and previoustarget and previoustarget.player and (previoustarget.player.ctfteam == toucher.player.ctfteam))
		return true
	end
	if toucher.player.ctfteam == mo.ctfteam then
		return true
	end
	if toucher.player.gotcrystal then
		return true
	end
	if previoustarget and previoustarget.valid then
		if previoustarget.player then
			previoustarget.player.gotcrystal = false
		end
		mo.lasttouched = previoustarget
	else
		mo.lasttouched = toucher
	end
	if mo.captured and (toucher.player) then
		mo.captured = nil
		mo.angle = 0
		mo.bank.chaosrings = $ & ~CHAOSRING_ENUM(mo.chaosring_num)
		mo.bank = nil
	end
	toucher.player.gotcrystal = true
	mo.target = toucher
	free(mo)
	mo.idle = nil
	mo.scale = mo.idealscale
	mo.ctfteam = 0
	P_SetObjectMomZ(toucher, toucher.momz/2)
	S_StartSound(mo,sfx_lvpass)
	if (splitscreen or (displayplayer and toucher.player == displayplayer)) or (displayplayer and previoustarget and previoustarget.player and previoustarget.player == displayplayer)
		S_StartSound(nil, sfx_kc5e)
	end
	toucher.spritexscale = toucher.scale
	toucher.spriteyscale = toucher.scale
	if not(previoustarget) then
		B.PrintGameFeed(toucher.player," picked up a "..CHAOSRING_TEXT(mo.chaosring_num).."!")
	elseif previoustarget.player
		B.PrintGameFeed(toucher.player," stole a "..CHAOSRING_TEXT(mo.chaosring_num).." from ",previoustarget.player,"!")
	end
	return true
end

local function captureChaosRing(mo, bank)
	mo.flags = $ & ~MF_SPECIAL
	bank.chaosrings = $|(CHAOSRING_ENUM[mo.chaosring_num])
	mo.bank = bank
	mo.captured = true
	addPoints(mo.target.player.ctfteam, 250)
	P_AddPlayerScore(mo.target.player, 250)
	mo.fuse = CHAOSRING_INVULNTIME
	mo.angle = $+(ANG1*60*mo.chaosring_num)
	mo.scale = mo.idealscale - (mo.idealscale/3)
	mo.ctfteam = mo.target.player.ctfteam
end

addHook("TouchSpecial", touchChaosRing, CHAOSRING_TYPE)

addHook("MobjFuse",function(mo)
	mo.flags = $|MF_SPECIAL
	return true
end,CHAOSRING_TYPE)

local function spawnChaosRing(num, chaosringnum)
	if not(CHAOSRING_SPAWNTABLE[num]) then
		return
	end

	if CHAOSRING_SPAWNTABLE[num].mo and CHAOSRING_SPAWNTABLE[num].mo.valid then
		return
	end
	local thing = CHAOSRING_SPAWNTABLE[num]
	local data = CHAOSRING_DATA[chaosringnum]
	--local z = ((thing.options & MTF_AMBUSH) and (thing.z+(24*FRACUNIT))) or thing.z
	local z = thing.z+(70*FRACUNIT)

	thing.mo = P_SpawnMobj(thing.x, thing.y, z, CHAOSRING_TYPE)
	thing.mo.scale = CHAOSRING_SCALE
	thing.mo.state = S_TEAMRING
	thing.mo.color = data.color
	thing.mo.chaosring_num = chaosringnum
	thing.mo.idealz = thing.mo.z
	thing.mo.idealscale = CHAOSRING_SCALE
	CHAOSRING_LIVETABLE[chaosringnum] = thing.mo
end

local CHAOSRING_AMBIENCE = freeslot("sfx_crng1")

sfxinfo[CHAOSRING_AMBIENCE].caption = "Chaos Ring presence"
sfxinfo[CHAOSRING_AMBIENCE].flags = $|SF_X2AWAYSOUND

local chaosRingFunc = function(mo)
	mo.shadowscale = FRACUNIT>>1
	
	-- Blink
	if mo.fuse&1
		mo.flags2 = $|MF2_DONTDRAW
	else
		mo.flags2 = $&~MF2_DONTDRAW
	end
	
	mo.angle = $+rotatespd
	
	-- Owner has been pushed by another player
	if mo.flags&MF_SPECIAL and mo.target and mo.target.valid 
	and mo.target.pushed_last and mo.target.pushed_last.valid
		touchChaosRing(mo,mo.target.pushed_last)
	end
	
	-- Owner has taken damage or has gone missing
	if mo.target and mo.target.player
		if not(mo.target.valid)
		or P_PlayerInPain(mo.target.player)
		or mo.target.player.playerstate != PST_LIVE
			if mo.target and mo.target.valid and mo.target.player then
				B.PrintGameFeed(mo.target.player," dropped the "..CHAOSRING_TEXT(mo.chaosring_num)..".")
			end
			mo.target.player.gotcrystal = false
			mo.target.player.gotcrystal_time = 0
			mo.target = nil
			B.ZLaunch(mo,FRACUNIT*bounceheight/2,true)
			--B.XYLaunch(mo,mo.angle,FRACUNIT*5)	
			P_InstaThrust(mo,mo.angle,FRACUNIT*5)
			free(mo)
			S_StartSound(mo, sfx_cdfm67)
		end
	end

	if mo.chaosring_corona and mo.chaosring_corona.valid then
		mo.chaosring_corona.fuse = max($, 2)
		mo.chaosring_corona.scale = mo.scale
		P_MoveOrigin(mo.chaosring_corona, mo.x, mo.y, mo.z+(P_MobjFlip(mo)*(mo.height/2)))
	else
		mo.chaosring_corona = P_SpawnMobjFromMobj(mo, 0,0,0, MT_INVINCIBLE_LIGHT)
		mo.chaosring_corona.frame = ($ & ~FF_TRANSMASK) | FF_TRANS80
		mo.chaosring_corona.blendmode = AST_ADD
		mo.chaosring_corona.target = mo
		mo.chaosring_corona.scale = mo.scale
		mo.chaosring_corona.spritexscale = FRACUNIT/2
		mo.chaosring_corona.spriteyscale = FRACUNIT/2
		mo.chaosring_corona.spriteyoffset = $+(FRACUNIT*5)
		mo.chaosring_corona.colorized = true
		mo.chaosring_corona.color = mo.color
		mo.chaosring_corona.fuse = 2
	end
	
	-- Unclaimed behavior
	if not(mo.target and mo.target.valid) then
		mo.flags = ($|MF_BOUNCE)&~MF_SLIDEME
		if mo.flags & MF_GRENADEBOUNCE == 0
			mo.flags = $|MF_NOGRAVITY
			local zz = mo.idealz + (sin(leveltime * ANG10) * 128)
			B.ZLaunch(mo, (zz - mo.z) / 120, false)
			
		else
			if not(leveltime%8) then
				local spark = P_SpawnMobjFromMobj(mo,0,0,0,MT_SUPERSPARK)
				spark.scale = mo.scale
				spark.colorized = true
				spark.color = mo.color
				spark.spriteyoffset = $-(FRACUNIT*6)
			end
			mo.flags = $&~MF_NOGRAVITY
			if P_IsObjectOnGround(mo)
				-- Bounce behavior
				B.ZLaunch(mo, FRACUNIT*bounceheight/2, true)
				S_StartSoundAtVolume(mo, sfx_tink, 100)
			end
		end
		-- Presence ambience
		if not S_SoundPlaying(mo, CHAOSRING_AMBIENCE)
			S_StartSound(mo, CHAOSRING_AMBIENCE)
		end
	else
		if S_SoundPlaying(mo, CHAOSRING_AMBIENCE)
			S_StopSoundByID(mo, CHAOSRING_AMBIENCE)
		end

		if not(leveltime%8) then
			local spark = P_SpawnMobjFromMobj(mo,0,0,0,MT_SUPERSPARK)
			spark.scale = mo.scale
			spark.colorized = true
			spark.color = mo.color
			spark.spriteyoffset = $-(FRACUNIT*6)
		end

		if mo.target.player and not(mo.fuse) then
		
			local capture = function(team, bank)
				local captime = CHAOSRING_CAPTIME
				local friendly = (splitscreen or (consoleplayer and consoleplayer.ctfteam == team))
				local sfx = friendly and SLOWCAPPINGALLY_SFX or SLOWCAPPINGENEMY_SFX
				mo.target.player.gotcrystal_time = ($~=nil and $+1) or 1
				mo.chaosring_capturing = true
				if mo.target.player.gotcrystal_time > captime then
					S_StartSound(nil, (friendly and sfx_kc5c) or sfx_kc46)
					mo.target.player.gotcrystal = false
					mo.target.player.gotcrystal_time = 0
					captureChaosRing(mo, bank)
					mo.target = bank
					return true
				else
					if mo.target.player.gotcrystal_time % 35 == 11 then
						S_StartSoundAtVolume(nil, sfx, 160)
					elseif mo.target.player.gotcrystal_time % 35 == 22 then
						S_StartSoundAtVolume(nil, sfx, 90)
					elseif mo.target.player.gotcrystal_time % 35 == 33 then
						S_StartSoundAtVolume(nil, sfx, 20)
					end
				end
			end
			
			if not P_IsObjectOnGround(mo.target) then
				mo.target.player.gotcrystal_time = 0
				return
			end
			if mo.target.player.ctfteam == 1 and P_MobjTouchingSectorSpecialFlag(mo.target, SSF_REDTEAMBASE)
				if capture(1,B.RedBank) then
					return
				end
			elseif mo.target.player.ctfteam == 2 and P_MobjTouchingSectorSpecialFlag(mo.target, SSF_BLUETEAMBASE)
				if capture(2,B.BlueBank) then
					return
				end
			else
				if mo.chaosring_capturing then
					mo.target.player.gotcrystal_time = 0
					mo.chaosring_capturing = nil
				end
			end
		end

		mo.flags = ($&~MF_BOUNCE)|MF_NOGRAVITY|MF_SLIDEME
		local t = mo.target
		--print(t.player)
		local ang = mo.angle
		local dist = mo.target.radius*3
		local x = t.x+P_ReturnThrustX(mo,ang,dist)
		local y = t.y+P_ReturnThrustY(mo,ang,dist)
		local z = t.z+abs(leveltime&63-31)*FRACUNIT/2 -- Gives us a hovering effect
		if P_MobjFlip(t) == 1 -- Make sure our vertical orientation is correct
			mo.flags2 = $&~MF2_OBJECTFLIP
		else
	-- 		z = $+t.height
			mo.flags2 = $|MF2_OBJECTFLIP
		end
		P_MoveOrigin(mo,t.x,t.y,t.z)
		P_InstaThrust(mo,R_PointToAngle2(mo.x,mo.y,x,y),min(FRACUNIT*60,R_PointToDist2(mo.x,mo.y,x,y)))
		mo.z = max(mo.floorz,min(mo.ceilingz+mo.height,z)) -- Do z pos while respecting level geometry
	end

	local cvar_pointlimit = CV_FindVar("pointlimit").value
	local cvar_overtime = CV_FindVar("overtime").value
	local cvar_timelimit = CV_FindVar("timelimit").value
	local overtime = ((cvar_overtime) and cvar_timelimit*60-leveltime/TICRATE <= 0)

	

	//Determine toss blink
	local tossblink = 0
	if mo.lasttouched and mo.lasttouched.valid and mo.lasttouched.player and not(mo.target) then
		tossblink = mo.lasttouched.player.tossdelay
	end

	if tossblink then
		
		local floorz = ((mo.flags2 & MF2_OBJECTFLIP) and mo.ceilingz-(FRACUNIT/2)) or mo.floorz+(FRACUNIT/2)

		if not(mo.floorvfx and (type(mo.floorvfx) == "table")) then
			mo.floorvfx = {}
		end

		local color = ((tossblink > (TICRATE/4)) and ({[1]=skincolor_redteam,[2]=skincolor_blueteam})[mo.lasttouched.player.ctfteam]) or SKINCOLOR_GOLD
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


	-- Ruby Control capture mechanics
	--[[
	
	--]]

end

local chaosRingPreFunc = function(mo)
	-- Press tossflag to toss ruby
	if not(mo.target and mo.target.valid and mo.target.player) then return end
	local player = mo.target.player
	local btns = player.cmd.buttons
	if (btns&BT_TOSSFLAG and not(player.powers[pw_carry] & CR_PLAYER) and not(player.powers[pw_super]) and not(player.tossdelay) and G_GametypeHasTeams())
		if player.gotcrystal then
			S_StartSound(mo, sfx_toss)
			B.PrintGameFeed(player," tossed a "..CHAOSRING_TEXT(mo.chaosring_num)..".")
			player.actioncooldown = TICRATE
			player.gotcrystal = false
			player.gotcrystal_time = 0
			player.tossdelay = TICRATE*2
			free(mo)
			if not (mo and mo.valid) then return end
			mo.target = nil
			P_MoveOrigin(mo,player.mo.x,player.mo.y,player.mo.z)
			B.ZLaunch(mo,player.mo.scale*6)
			P_InstaThrust(mo,player.mo.angle,player.mo.scale*15)
		end
	end
end


COM_AddCommand("chring", function(player)
	for i = 1, 6 do
		spawnChaosRing(i, i)
	end
end)

addHook("MobjThinker", chaosRingFunc, MT_BATTLE_CHAOSRING)
addHook("PreThinkFrame", do
	for i = 1, 7 do
		if CHAOSRING_LIVETABLE[i] and CHAOSRING_LIVETABLE[i].valid then
			chaosRingPreFunc(CHAOSRING_LIVETABLE[i])
			continue
		end
	end
end)


addHook('ThinkFrame', do
	if gametype != GT_BANK
		return
	end

	if CHAOSRING_WINCOUNTDOWN == 0 then
		B.Arena.ForceWin()
		CHAOSRING_WINCOUNTDOWN = -1
	elseif CHAOSRING_WINCOUNTDOWN > 0
		for i = 1, 2 do
			local bank = (i==1 and B.RedBank) or B.BlueBank
			if bank.chaosrings == (CHAOSRING1|CHAOSRING2|CHAOSRING3|CHAOSRING4|CHAOSRING5|CHAOSRING6)
				CHAOSRING_WINCOUNTDOWN = $-1
			end
		end
	end

	for i = 1, 6 do
		local chaosring = CHAOSRING_LIVETABLE[i]

		if not(chaosring and chaosring.valid) then
			table.remove(CHAOSRING_LIVETABLE, i)
			continue
		end

		-- rev: remove ruby if on a "remove ctf flag" sector type
		/*local sector = chaosring.subsector.sector --P_MobjTouchingSectorSpecialFlag(chaosring, 0) or chaosring.subsector.sector --P_ThingOnSpecial3DFloor(chaosring) or chaosring.subsector.sector
		local ruby_in_goop = chaosring.eflags&MFE_GOOWATER
		local on_rflagbase = (GetSecSpecial(sector.special, 4) == 3) or (sector.specialflags&SSF_REDTEAMBASE)
		local on_bflagbase = (GetSecSpecial(sector.special, 4) == 4) or (sector.specialflags&SSF_BLUETEAMBASE)
		local on_return_sector = P_MobjTouchingSectorSpecialFlag(chaosring, SSF_RETURNFLAG) -- rev: i don't know if this even works..
		local plr_has_ruby = chaosring.target and chaosring.target.valid

		if not plr_has_ruby and (ruby_in_goop or (on_rflagbase or on_bflagbase or on_return_sector)) then
			--print("fell into removal sector")
			if (chaosring.target and chaosring.target.valid) then
				B.PrintGameFeed(player, " dropped the "+CHAOSRING_TEXT(chaosring.chaosring_num)+".")
			end

			P_RemoveMobj(chaosring)
			table.remove(CHAOSRING_LIVETABLE, i)
			continue
		end*/

			-- Idle timer
		if chaosring.idle != nil and not(chaosring.captured) then 
			chaosring.idle = $-1
			if chaosring.idle == 0
				if chaosring.ctfteam
					-- Remove team protection
					chaosring.idle = nil
					chaosring.ctfteam = 0
				else
					-- Remove object
					P_SpawnMobj(chaosring.x,chaosring.y,chaosring.z,MT_SPARK)
					P_RemoveMobj(chaosring)
					table.remove(CHAOSRING_LIVETABLE, i)
					continue
				end
			end
		end
	end

	local rs = redscore
	local bs = bluescore
	local blueInBlue = 0
	local blueInRed = 0
	local redInBlue = 0
	local redInRed = 0
	
	-- Get player-to-base statuses
	for player in players.iterate do
		if player.mo and player.rings >= 100
			highValueSparkle(player)
		end
		if player.mo and player.mo.health and not player.powers[pw_flashing]
			local base = getBase(player)
			if base == 1 -- Red base
				if player.ctfteam == 1
					redInRed = $+1
				else
					blueInRed = $+1
				end
			elseif base == 2 -- Blue base
				if player.ctfteam == 1
					redInBlue = $+1
				else
					blueInBlue = $+1
				end
			end
		end
	end

	-- Do player in base transactions
	for player in players.iterate do
		if player.mo and player.mo.health and not player.powers[pw_flashing] and not(player.gotcrystal)
			local base = getBase(player)
			if base == 1 -- Red base
				if redInRed and blueInRed
					continue
				end
			elseif base == 2 -- Blue base
				if redInBlue and blueInBlue
					continue
				end
			end
			if base != 0
				baseTransaction(player, base)
			end
		end
		if B.RedBank and B.RedBank.valid
			-- Color
			if redInRed and blueInRed
				B.RedBank.color = flashColor(SKINCOLOR_TANGERINE, SKINCOLOR_TOPAZ, 8)
			elseif redInRed
				B.RedBank.color = flashColor(SKINCOLOR_SUPERRED1, SKINCOLOR_SUPERRED5, 16)
			elseif blueInRed
				B.RedBank.color = flashColor(SKINCOLOR_SUNSET, SKINCOLOR_FOUNDATION, 16)
			else
				B.RedBank.color = SKINCOLOR_CRIMSON
			end
			-- Transparency
			B.RedBank.frame = $ | FF_TRANS30
			-- Motion
			B.RedBank.z = B.RedBank.floorz + B.RedBank.scale * 16 + FixedMul(sin(leveltime * ANG10), B.RedBank.scale * 8)
			-- HUD sparkle
			if rs < redscore
				addHudSparkle(1, 1)
			elseif rs > redscore
				addHudSparkle(1, 0)
			end
		end
		if B.BlueBank and B.BlueBank.valid
			-- Color
			if redInBlue and blueInBlue
				B.BlueBank.color = flashColor(SKINCOLOR_NOBLE, SKINCOLOR_PASTEL, 8)
			elseif redInBlue
				B.BlueBank.color = flashColor(SKINCOLOR_MIDNIGHT, SKINCOLOR_VIOLET, 16)
			elseif blueInBlue
				B.BlueBank.color = flashColor(SKINCOLOR_ICY, SKINCOLOR_ARCTIC, 16)
			else
				B.BlueBank.color = SKINCOLOR_COBALT
			end
			-- Transparency
			B.BlueBank.frame = $ | FF_TRANS30
			-- Motion
			B.BlueBank.z = B.BlueBank.floorz + B.BlueBank.scale * 16 + FixedMul(sin(leveltime * ANG10), B.BlueBank.scale * 8)
			-- HUD sparkle
			if bs < bluescore
				addHudSparkle(0, 1)
			elseif bs > bluescore
				addHudSparkle(0, 0)
			end
		end
	end	
end)

addHook('NetVars', function(net)
	B.RedBank = net($)
	B.BlueBank = net($)
	CHAOSRING_SPAWNTABLE = net($)
	CHAOSRING_WINCOUNTDOWN = net($)
	CHAOSRING_LIVETABLE = net($)
end)