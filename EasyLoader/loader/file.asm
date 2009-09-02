.print ">file.asm"

F_LAUNCH_FILE:{
	.if(KERNEL_API){
		lda #$00
	}
}
F_LAUNCH_FILE_PART2:{
	.if(KERNEL_API){
		beq !skip+
		jmp F_LAUNCH_FILE_REAL_PART2
	!skip:
	}

	jsr F_LAST_CONFIG_WRITE

	/*
	** CARTRIDGE IS ACTIVE
	** DATA in $02-$7fff
	**
	** EXTRACT DATA
	**
	** COPY ALL REQUIRED TO $7000+
	*/

	jsr F_RESET_GRAPHICS

	// disable rom at $a000
	lda #MODE_8k
	sta IO_MODE

	// copy bank,offset,size,loadaddr (part 1)
	ldy #O_DIR_BANK
!loop:
	lda (ZP_ENTRY), y
	sta $7005-O_DIR_BANK, y
	iny
	cpy #V_DIR_SIZE
	bne !loop-
	
	// create interger of loadaddr
	
	// comvert bin->bcd
	:mov16 $7005-O_DIR_BANK + O_DIR_LOADADDR ; P_BINBCD_IN
	jsr F_BINBCD_16BIT
	// convert bcd->petscii
	ldx #$00
	lda P_BINBCD_OUT+2
	jsr F_BCDIFY_LOWER_BUF
	lda P_BINBCD_OUT+1
	jsr F_BCDIFY_BUF
	lda P_BINBCD_OUT+0
	jsr F_BCDIFY_BUF
	// srtip leading spaces
	ldx #0
!loop:
	lda P_BUFFER,x
	cmp #$30
	bne !skip+
	:mov #$20 ; P_BUFFER,x
	inx
	cmp #4
	bne !loop-
!skip:
	// copy to save place
	ldx #4
!loop:
	lda P_BUFFER,x
	sta $7000,x
	dex
	bpl !loop-
	
	/*
	** DO A PARTIAL RESET (DATA <$7000 IS LOST)
	*/
	
	// do a partial reset
	ldx #$ff
	txs
	ldx #$05
	stx $d016
	jsr $fda3
	jsr $fd50
	jsr $fd15
	jsr $ff5b

	/*
	** SETUP A HOOK IN THE CHRIN VECTOR
	** COPY REQUIRED PROGRAM+DATA TO $33c+
	*/

	// copy (int of loadaddr),bank,offset,size,loadaddr (part 2)
	ldy #O_DIR_BANK
!loop:
	lda $7000-O_DIR_BANK, y
	sta RES_DATA-O_DIR_BANK, y
	iny
	cpy #5+V_DIR_SIZE
	bne !loop-
	
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
		jmp FILE_COPIER
	RES_DATA:
	}
	FCOPY1_END:

	/*
	** BACK IN CARTRIDGE
	** COPY NEEDED DATE IN SAFE ZP AND $100+
	** COPY SHORT PROG TO $100+
	*/


FILE_COPIER:
	// display >LOADING "xxx",EF,1<

	ldy #0
!loop:
	lda loading_1, y
	jsr $ffd2
	iny
	cpy #[loading_1_end - loading_1]
	bne !loop-

	ldy #0
!loop:
	lda RES_DATA+5-O_DIR_BANK + O_DIR_UNAME, y
	beq !skip+
	jsr $ffd2
	iny
	cpy #16
	bne !loop-
!skip:

	ldy #0
!loop:
	lda loading_2, y
	jsr $ffd2
	iny
	cpy #[loading_2_end - loading_2]
	bne !loop-



	.const ZP_BANK = $ba
	.const ZP_SIZE = $07 // $08 - Temporary Integer during OR/AND
	.const ZP_SRC = $b7 // $b8
	.const ZP_DST = $ae // $af

	// copy bank
	:mov RES_DATA+5-O_DIR_BANK + O_DIR_BANK ; ZP_BANK
	
	// copy size-2 
	:sub16 RES_DATA+5-O_DIR_BANK + O_DIR_SIZE ; #2 ; ZP_SIZE
	// (dont load the laod address)
	
	// copy offset whithin first bank
	:add16 RES_DATA+5-O_DIR_BANK + O_DIR_OFFSET ; #2 ; ZP_SRC
	// add 2 (don't load the loadaddress)

	// if the offset is now >= $4000 switch to next bank
	:if ZP_SRC+1 ; EQ ; #$40 ; ENDIF ; !endif+
		lda #$00
		sta ZP_SRC+1
		inc ZP_BANK
	!endif:
	// make offset ($0000-$3fff) to point into real address ($8000-$bfff)
	:add ZP_SRC+1 ; #$80
	
	// copy dst address
	:mov16 RES_DATA+5-O_DIR_BANK + O_DIR_LOADADDR ; ZP_DST

	:if16 ZP_DST ; LE ; #$0801 ; ELSE ; !else+
		// LOAD ADDR $200-$0801 -> run
		lda #$52
		sta $277
		lda #$55
		sta $278
		lda #$4e
		sta $279
		lda #$0d
		sta $27a
		lda #$04
		sta $c6
		jmp !endif+
	!else:
		lda #$53
		sta $277
		lda #$59
		sta $278
		lda #$53
		sta $279
		
		ldx #4
	!loop:
		lda RES_DATA, x
		sta $27a, x
		dex
		bpl !loop-
		lda #$08
		sta $c6
	
	!endif:


	// setup back-jump
.if(KERNEL_API){
	:mov16 #kernel_lander ; $100
}

F_LAUNCH_FILE_REAL_PART2:

	// copy laucher to $100
	ldx #[FCOPY2_END-FCOPY2_START]-1
!loop:
	lda FCOPY2_START, x
	sta add_bank, x
	dex
	bpl !loop-
		


	// update size (for faked start < 0)
	:add16_8 ZP_SIZE ; ZP_SRC
	
	// lower source -> y ; copy always block-wise
	:sub16_8 ZP_DST ; ZP_SRC
	ldy ZP_SRC
	:mov #0 ; ZP_SRC
	
	:if ZP_SIZE+1 ; NE ; #$00 ; JMP ; COPY_FILE
	sty smc_limit+1
	jmp COPY_FILE_LESS_THEN_ONE_PAGE

	/*
	** CART IS FILE (AND NO LONGER EASYLOADER)
	** COPY THE REQUIRED PROG
	*/

	.const kernel_jumper = $100

	FCOPY2_START:
	.pseudopc $102 {
	add_bank:
		:mov #$80 ; ZP_SRC+1
		inc ZP_BANK
	COPY_FILE:
		lda ZP_BANK
		sta $de00
	!loop:
		lda (ZP_SRC), y
		sta (ZP_DST), y
		iny
		bne !loop-
		inc ZP_DST+1
		inc ZP_SRC+1
		dec ZP_SIZE+1
		beq !skip+
		:if ZP_SRC+1 ; EQ ; #$c0 ; add_bank
		jmp !loop-
		
	!skip:
		:if ZP_SRC+1 ; EQ ; #$c0 ; ENDIF ; !endif+
			:mov #$80 ; ZP_SRC+1
			inc ZP_BANK
	COPY_FILE_LESS_THEN_ONE_PAGE:
			lda ZP_BANK
			sta $de00
		!endif:
		ldy ZP_SIZE
		beq !skip+
	!loop:
		dey
		lda (ZP_SRC), y
		sta (ZP_DST), y
	smc_limit:
		cpy #$00
		bne !loop-

	!skip:

		// maybe an early exit
.if(KERNEL_API){
		jmp (kernel_jumper)
}
	kernel_lander:


		// setup end of program
		:mov16 #$0801 ; $2b
		:add16_8 ZP_DST ; ZP_SIZE ; $2d
		:mov16 $2d ; $2f
		:mov16 $2d ; $31
		:mov16 $2d ; $ae

	/*
	** DISABLE CART, RESTORE REGS, JUMP TO THE REAL CHRIN
	*/

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

loading_1:
	.byte $91
	.text "LOADING "
	.byte $22
loading_1_end:
loading_2:
	.byte $22
	.text ",EF,1"
	.byte $0d
	.text "READY."
	.byte $0d, $0d
loading_2_end:
}

/*

SIZE: +++tttttttt
SRC:  ...bBBBBbbb.

*/
