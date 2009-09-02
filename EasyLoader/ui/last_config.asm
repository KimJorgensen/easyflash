.print ">last_config.asm"

.const P_LAST_CONFIG_ADDRESS = $fff0

F_LAST_CONFIG_READ:{

	ldx #[copy_end - copy_start]-1
!loop:
	lda copy_start, x
	sta copy, x
	dex
	bpl !loop-

	jsr copy

	lda P_DRAW_START
	clc
	adc P_DRAW_OFFSET
	clc
	adc P_BINBCD_IN
	cmp #$65
	bne fresh_start

	// just belive we're right
	rts

fresh_start:
	lda #0
	sta P_DRAW_START // show first line
	sta P_DRAW_OFFSET // first line is active
	rts
	
copy_start:
.pseudopc $200 {
copy:
	:mov #$30 ; $01
	:mov P_LAST_CONFIG_ADDRESS+0 ; P_DRAW_START
	:mov P_LAST_CONFIG_ADDRESS+1 ; P_DRAW_OFFSET
	:mov P_LAST_CONFIG_ADDRESS+2 ; P_BINBCD_IN
	:mov #$37 ; $01
	rts	
}
copy_end:
	
}

F_LAST_CONFIG_WRITE:{

	lda #$65
	sec
	sbc P_DRAW_START
	sec
	sbc P_DRAW_OFFSET
	sta P_LAST_CONFIG_ADDRESS+2

	:mov P_DRAW_START ; P_LAST_CONFIG_ADDRESS+0
	:mov P_DRAW_OFFSET ; P_LAST_CONFIG_ADDRESS+1

	rts
}