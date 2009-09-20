.print ">last_config.asm"

.const P_LAST_CONFIG_ADDRESS = $dffc

F_LAST_CONFIG_READ:{

	:mov P_LAST_CONFIG_ADDRESS+0 ; P_DRAW_START
	:mov P_LAST_CONFIG_ADDRESS+1 ; P_DRAW_OFFSET

	lda P_DRAW_START
	clc
	adc P_DRAW_OFFSET
	clc
	adc P_LAST_CONFIG_ADDRESS+2
	cmp #$65
	bne fresh_start

	// just belive we're right
	rts

fresh_start:
	lda #0
	sta P_DRAW_START // show first line
	sta P_DRAW_OFFSET // first line is active
	
	jsr F_LAST_CONFIG_WRITE
	
	:copy_to_df00 copy_scan_boot_start ; [copy_scan_boot_end - copy_scan_boot_start]
	jmp scan_boot // does a rts it not found

copy_scan_boot_start:
	.pseudopc $df00 {
		.const TEMP = $02
		end_scan:
			:mov #EASYLOADER_BANK ; $de00
	rts	
		scan_boot:
			:mov #EASYFILESYSTEM_BANK ; $de00
			:mov16 #$a000-V_EFS_SIZE ; TEMP
		big_loop:
			:add16_8 TEMP ; #V_EFS_SIZE
		
			ldy #O_EFS_TYPE
			lda (TEMP), y
			and #O_EFST_MASK
			cmp #O_EFST_END
			beq end_scan // type = end of fs
			and #$10
			beq big_loop // not of type crt
		
			ldy #$ff
			// check B
			jsr get_char
			cmp #$42
			bne big_loop
			// check O
			jsr get_char
			cmp #$4f
			bne big_loop
			// check O
			jsr get_char
			cmp #$4f
			bne big_loop
			// check T
			jsr get_char
			cmp #$54
			bne big_loop
			// check . or \0
			jsr get_char
			cmp #$00
			beq found_boot
			cmp #$2e
			bne big_loop
			// check C
			jsr get_char
			cmp #$43
			bne big_loop
			// check R
			jsr get_char
			cmp #$52
			bne big_loop
			// check T
			jsr get_char
			cmp #$54
			bne big_loop
			// check \0
			iny
			lda (TEMP), y
			bne big_loop
	
		found_boot:
			ldy #O_EFS_TYPE
			lda (TEMP), y
			and #$03
			tax
			lda type2mode_table, x
			tax
			iny
			lda (TEMP), y
			sta $de00
			stx $de02
			jmp ($fffc)
			
		get_char:
			iny
			lda (TEMP), y
			:if A ; GE ; #$61 ; ENDIF ; !endif+
				eor #$20
			!endif:
			rts
		
		type2mode_table:
			.byte MODE_8k
			.byte MODE_16k
			.byte MODE_ULT
			.byte MODE_ULT

	}
copy_scan_boot_end:
	
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