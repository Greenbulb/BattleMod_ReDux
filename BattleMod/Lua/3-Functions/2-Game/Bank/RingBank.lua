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
	else
		B.BlueBank = mo
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

local CHAOSRING_STARTSPAWNBUFFER = TICRATE*2 --Time it takes for Chaos Rings to start spawning
local CHAOSRING_SPAWNBUFFER = TICRATE*46 --Chaos rings spawn every X seconds
local CHAOSRING_SCALE = FRACUNIT
local CHAOSRING_TYPE = MT_BATTLE_CHAOSRING
local CHAOSRING_ANGLESPEED = ANG1*8

local CHAOSRING_SPAWNTABLE = {}
local CHAOSRING_LIVETABLE = {nil, nil, nil, nil, nil, nil} --Table where you can get each Chaos ring's Object

local CHAOSRING_DATA = {
	[1] = { --Gold
		color = SKINCOLOR_GOLDENROD
	},

	[2] = { --Light Blue
		color = SKINCOLOR_SKY
	},

	[3] = { --Green
		color = SKINCOLOR_MASTER
	},

	[4] = { --Pink
		color = SKINCOLOR_FANCY
	},

	[5] = { --Purple
		color = SKINCOLOR_PURPLE
	},

	[6] = { --Blue
		color = SKINCOLOR_SAPPHIRE
	}
}

addHook('MapLoad', do

	CHAOSRING_SPAWNTABLE = {} --Clear the table

	for mt in mapthings.iterate do
		if mt and (mt.type == 321) and mt.valid then --Match Chaos Emerald Spawn

			local chaosring_spawn = { --Data for the spawn
				x = mt.x*FRACUNIT,
				y = mt.y*FRACUNIT,
				z = mt.z*FRACUNIT,
				options = mt.options,
				mo = nil --Will use this field later
			}

			table.insert(CHAOSRING_SPAWNTABLE, chaosring_spawn)
			print("Inserted chaosring_spawn #"..#CHAOSRING_SPAWNTABLE)
		end
	end
end)

local freetics = TICRATE
local idletics = TICRATE*16

local function free(mo)
	if not (mo and mo.valid) then return end
	--print(true)
	mo.fuse = freetics
	mo.flags = $&~MF_SPECIAL
	mo.flags = $|MF_GRENADEBOUNCE
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
	
	mo.target = toucher
	free(mo)
	mo.idle = nil
	mo.ctfteam = 0
	P_SetObjectMomZ(toucher, toucher.momz/2)
	S_StartSound(mo,sfx_lvpass)
	if (splitscreen or (displayplayer and toucher.player == displayplayer)) or (displayplayer and previoustarget and previoustarget.player and previoustarget.player == displayplayer)
		S_StartSound(nil, sfx_kc5e)
	end
	toucher.spritexscale = toucher.scale
	toucher.spriteyscale = toucher.scale
	if not(previoustarget) then
		--B.PrintGameFeed(toucher.player," picked a "..rubytext.."!")
	else
		--B.PrintGameFeed(toucher.player," stole the "..rubytext.." from ",previoustarget.player,"!")
	end
	return true
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
	local z = thing.z+(25*FRACUNIT)

	thing.mo = P_SpawnMobj(thing.x, thing.y, z, CHAOSRING_TYPE)
	thing.mo.scale = CHAOSRING_SCALE
	thing.mo.state = S_TEAMRING
	thing.mo.color = data.color
	thing.mo.chaosring_num = chaosringnum
	CHAOSRING_LIVETABLE[chaosringnum] = thing.mo
end

local function thinkChaosRing(mo)

	if mo.chaosring_corona and mo.chaosring_corona.valid then
		mo.chaosring_corona.fuse = max($, 2)
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

	mo.angle = $+CHAOSRING_ANGLESPEED

	if mo.target and mo.target.valid then
		local player = mo.target.player
		local btns = player.cmd.buttons
		if (btns&BT_TOSSFLAG and not(player.powers[pw_carry] & CR_PLAYER) and not(player.powers[pw_super]) and not(player.tossdelay) and G_GametypeHasTeams())
			if player.gotcrystal then
				S_StartSound(mo, sfx_toss)
				--B.PrintGameFeed(player," tossed the "..rubytext..".")
				player.actioncooldown = TICRATE
				player.gotcrystal = false
				player.gotcrystal_time = 0
				player.tossdelay = TICRATE*2
				free(mo)
				if not (mo and mo.valid) then continue end
				mo.target = nil
				P_MoveOrigin(mo,player.mo.x,player.mo.y,player.mo.z)
				B.ZLaunch(mo,player.mo.scale*6)
				P_InstaThrust(mo,player.mo.angle,player.mo.scale*15)
			end
		end
		-- Owner has been pushed by another player
		if mo.flags&MF_SPECIAL and mo.target and mo.target.valid 
		and mo.target.pushed_last and mo.target.pushed_last.valid
			touchChaosRing(mo,mo.target.pushed_last)
		end

		mo.flags = ($&~MF_BOUNCE)|MF_NOGRAVITY|MF_SLIDEME
		local t = mo.target
		local player = t.player
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
		--P_MoveOrigin(mo,t.x,t.y,t.z)
		P_InstaThrust(mo,R_PointToAngle2(mo.x,mo.y,x,y),min(FRACUNIT*60,R_PointToDist2(mo.x,mo.y,x,y)))
		mo.z = max(mo.floorz,min(mo.ceilingz+mo.height,z)) -- Do z pos while respecting level geometry
	end
end

COM_AddCommand("chring", function(player)
	for i = 1, 6 do
		spawnChaosRing(i, i)
	end
end)



addHook('ThinkFrame', do
	if gametype != GT_BANK
		return
	end

	local rs = redscore
	local bs = bluescore
	local blueInBlue = 0
	local blueInRed = 0
	local redInBlue = 0
	local redInRed = 0


	--Chaos Rings
	for i = 1, 6 do
		local chaosring = CHAOSRING_LIVETABLE[i]

		if not(chaosring and chaosring.valid) then
			table.remove(CHAOSRING_LIVETABLE, i)
			continue
		end

		thinkChaosRing(chaosring)
	end
	
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
		if player.mo and player.mo.health and not player.powers[pw_flashing]
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
end)