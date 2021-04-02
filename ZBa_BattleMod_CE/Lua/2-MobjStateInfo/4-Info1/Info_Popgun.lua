mobjinfo[MT_CORK].speed = 60*FRACUNIT

freeslot(
	"spr_fair",
	"s_fangchar_airfire1",
	"s_fangchar_airfire2"
)

states[S_FANGCHAR_AIRFIRE1] = {
        sprite = SPR_FAIR,
        frame = A,
        nextstate = S_FANGCHAR_AIRFIRE1
}

states[S_FANGCHAR_AIRFIRE2] = {
        sprite = SPR_FAIR,
        frame = B,
        nextstate = S_FANGCHAR_AIRFIRE2
}
