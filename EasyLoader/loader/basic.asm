.print ">basic.asm"

.if(! KERNEL_API){

F_BASIC:{
	
	jsr F_LAST_CONFIG_WRITE

	// set screen $20
	lda #$20
	ldx #$00
!loop:
	.for(var i=0; i<4; i++){
		sta $0400+i*$100, x
	}
	dex
	bne !loop-

	ldx #[F_BASIC_SUB_end - F_BASIC_SUB_beginn]-1
!loop:
	lda F_BASIC_SUB_beginn, x
	sta $02, x
	dex
	bpl !loop-

	jmp $02

F_BASIC_SUB_beginn:{
	lda #MODE_RAM
	sta IO_MODE
	jmp ($fffc)
}
F_BASIC_SUB_end:

}


}else{

F_LAUNCH_SUB:{
	:lday( ZP_ENTRY , O_DIR_BANK )
	sta $7000
	:lday( ZP_ENTRY , O_DIR_OFFSET+0 )
	sta $7001
	:lday( ZP_ENTRY , O_DIR_OFFSET+1 )
	ora #$80
	sta $7002
	
	jmp F_BASIC_PART2
}


F_BASIC:{
	:mov #$00 ; $7000
	:mov16 #$a000 ; $7001
}

F_BASIC_PART2:{

	jsr F_LAST_CONFIG_WRITE

	jsr F_RESET_GRAPHICS

	// copy restter to $7777
	ldx #[FCOPY0_END-FCOPY0_START]-1
!loop:
	lda FCOPY0_START, x
	sta part_reset, x
	dex
	bpl !loop-
	


	// do a partial reset
	ldx #$ff
	txs
	ldx #$05
	stx $d016
	jmp part_reset
	
FCOPY0_START:
.pseudopc $7777 {
part_reset:
	:mov #MODE_RAM ; IO_MODE
	jsr $fda3
	jsr $fd50
	jsr $fd15
	jsr $ff5b
	:mov #MODE_16k ; IO_MODE
	jmp FCOPY0_END
}
FCOPY0_END:

	// copy laucher to $33c
	ldx #[FCOPY1_END-FCOPY1_START]-1
!loop:
	lda FCOPY1_START, x
	sta $33c, x
	dex
	bpl !loop-
	
	// change CHRIN vector
	lda $324
	sta SMC_RESTORE_LOWER+1
	lda $325
	sta SMC_RESTORE_UPPER+1

	// add our vector
	:mov16 #RESET_TRAP ; $324

	/*
	** DO THE REST OF THE RESET (CODE+DATA IN $33c+)
	*/

	// continue reset-routine
	jmp GO_RESET
	

	FCOPY1_START:
	.pseudopc $33c {
	GO_RESET:
		:mov #MODE_RAM ; IO_MODE
		jmp $fcfe

	/*
	** RESET IS DONE
	** RESTORE VECTOR
	** JUMP BACK IN CARTRIDGE
	*/

	RESET_TRAP:
		// restore A,X,Y
		sei
		pha
		txa
		pha
		tya
		pha

		// restore_vector (by self-modifying-code)
	SMC_RESTORE_LOWER:
		lda #$00
		sta $324
	SMC_RESTORE_UPPER:
		lda #$00
		sta $325
	
		// activate easyloader programm
		lda #MODE_16k
		sta IO_MODE
		
		// jump back to program
		jmp INISTALL_ROUTINE
	RES_DATA:
	}
	FCOPY1_END:

	INISTALL_ROUTINE:
		jsr F_INIT_KERNEL_API
		
	// copy laucher to $100
	ldx #[FCOPY2_END-FCOPY2_START]-1
!loop:
	lda FCOPY2_START, x
	sta $100, x
	dex
	bpl !loop-
		
	jmp CONTINUE
	
	FCOPY2_START:
	.pseudopc $100 {
		CONTINUE:
		// disable cart
		:mov #MODE_RAM ; IO_MODE
		
		// restore A,X,Y
		pla
		tay
		pla
		tax
		pla
		
		cli
		jmp ($324)
	}
	FCOPY2_END:


}






}