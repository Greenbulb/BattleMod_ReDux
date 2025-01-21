freeslot("sfx_piwvt", "sfx_piwve", "SPR2_TWRL", "SPR2_ATWR", "S_AMY_PIKOTWIRL")

sfxinfo[sfx_piwvt].caption = "Piko Wave Ready"
sfxinfo[sfx_piwve].caption  = "\x82".."PIKO WAVE READY".."\x80"

spr2defaults[SPR2_TWRL] = SPR2_TWIN
spr2defaults[SPR2_ATWR] = SPR2_TWIN


states[S_AMY_PIKOTWIRL] = {
    sprite = SPR_PLAY, 
    frame = SPR2_ATWR|FF_ANIMATE|A, 
    tics = 10,
    nextstate = S_PLAY_JUMP, 
    var1 = 7,
    var2 = 1
}