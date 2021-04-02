freeslot("MT_PIKOWAVE", "MT_PIKOWAVEHEART", "S_PIKOWAVE1", "S_PIKOWAVE2", "S_PIKOWAVE3", "spr_bhrt", "sfx_hamrc")

mobjinfo[MT_PIKOWAVE] = {
	spawnstate = S_PIKOWAVE1,
	xdeathstate = S_SPRK1,
	spawnhealth = 1000,
	reactiontime = 8,
	speed = 60*FRACUNIT,
	radius = 6*FRACUNIT,
	height = 12*FRACUNIT,
	mass = 0,
	damage = 0,
	flags = MF_NOGRAVITY|MF_BOUNCE
}
mobjinfo[MT_PIKOWAVEHEART] = {
	spawnstate = S_PIKOWAVE2,
	deathstate = S_SPRK1,
	xdeathstate = S_SPRK1,
	radius = 24*FRACUNIT,
	height = 24*FRACUNIT,
	damage = 1,
	cantouchteam = true,
	blockable = 1,
	block_stun = 6,
	block_hthrust = 10,
	block_vthrust = 3,
	flags = MF_NOBLOCKMAP|MF_MISSILE
}
mobjinfo[MT_LHRT].blockable = 1
mobjinfo[MT_LHRT].block_stun = 3
mobjinfo[MT_LHRT].block_hthrust = 6
mobjinfo[MT_LHRT].block_vthrust = 2

states[S_PIKOWAVE1] = {
	sprite = SPR_BHRT,
	frame = FF_PAPERSPRITE|B
}
states[S_PIKOWAVE2] = {
	sprite = SPR_BHRT,
	frame = FF_TRANS20|A
}
states[S_PIKOWAVE3] = {
	sprite = SPR_BHRT,
	frame = FF_TRANS20|B
}