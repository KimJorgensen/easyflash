.print ">search.asm"

F_SEARCH_INIT:{
	:mov #0 ; P_SEARCH_POS
	:mov #0 ; P_SEARCH_START
	ldx P_NUM_DIR_ENTRIES
	dex
	stx P_SEARCH_COUNT
	rts
}

.const P_SEARCH_SCREEN_OUT = $0400 + 24*40 + 3

F_SEARCH_KEY:{
	.const char = P_BINBCD_OUT+0
	.const start = P_BINBCD_OUT+1
	.const count = P_BINBCD_OUT+2
	.const max_count = P_BINBCD_IN+0

	// laod pos
	ldx P_SEARCH_POS
	// check for 16 chars
	cpx #V_SEARCH_MAX_CHAR
	bne !skip+
	rts
!skip:
	// fine
	// store them
	sta char
	sta P_SEARCH_SCREEN_OUT, x
	lda P_SEARCH_START, x
	sta start
	lda P_SEARCH_COUNT, x
	sta count
	sta max_count
	// inc to next pos
	inx
	stx P_SEARCH_POS
	
	// if the prev. search narrows it to one -> we're done
	lda P_SEARCH_COUNT
	cmp #1
	beq done
	
	// ok, search for the first and last occ. whithin the specified entries

	// abslute first entry
	:mov16 #P_DIR - V_DIR_SIZE ; ZP_ENTRY
	// go to the start offset
	ldx start
	beq !skip+
!loop:
	:add16_8 ZP_ENTRY ; #V_DIR_SIZE
	dex
	bne !loop-
!skip:
	
	// setup filename-position
	:add P_SEARCH_POS ; #O_DIR_UNAME-1 ; A
	tay
	
	// correct count
	:mov #0 ; count
	dec start
	
search_start:
	// go to next entry
	:add16_8 ZP_ENTRY ; #V_DIR_SIZE
	inc start

	// find first entry whith that char
	lda (ZP_ENTRY), y
	cmp char
	bcc next_line // match too low
	beq search_end // found a char
	bne not_found // didn't found the char
	
next_line:
	// decrement max counter
	dec max_count
	// if not empty -> try next line
	bne search_start
not_found:
	// entry not found!
	dec count
	bne error_last_file
error_next_file:
	// jump to the next file
	inc start
error_last_file:
	// we're already on the last line: don't advance
	:mov #1 ; count
	jmp done

search_end:
	// go to next entry
	:add16_8 ZP_ENTRY ; #V_DIR_SIZE
	inc count

	// find first entry whith that char
	lda (ZP_ENTRY), y
	cmp char
//	bcc next_line // match too low -- can't happen
	beq next_line_end // found a char
	bne done // didn't found the char
	
next_line_end:
	dec max_count
	beq done
	bne search_end
	
done:
	ldx P_SEARCH_POS
	:mov start ; P_SEARCH_START, x
	sta P_DRAW_START
	:mov count ; P_SEARCH_COUNT, x
	
	:mov #0 ; P_DRAW_OFFSET
	jsr F_DRAW // includes rts
	jmp deb_sea
}

F_SEARCH_DEL:{
	dec P_SEARCH_POS
	beq F_SEARCH_RESET
	bmi F_SEARCH_RESET
	ldx P_SEARCH_POS
	lda #$82
	sta P_SEARCH_SCREEN_OUT, x
	:mov P_SEARCH_START, x ; P_DRAW_OFFSET
	:mov #0 ; P_DRAW_START
	jsr F_DRAW // includes rts
	jmp deb_sea
}

F_SEARCH_RESET:{
	ldx P_SEARCH_POS
	lda #$82
!loop:
	sta P_SEARCH_SCREEN_OUT, x
	dex
	bpl !loop-
	:mov #0 ; P_SEARCH_POS
//	rts
}

deb_sea:{
	ldx #0
	ldy P_SEARCH_POS
	lda P_SEARCH_START, y
	sta P_BINBCD_IN
	jsr F_BINBCD_8BIT
	lda P_BINBCD_OUT+1
	jsr F_BCDIFY_BUF
	lda P_BINBCD_OUT+0
	jsr F_BCDIFY_BUF
	lda #$82
	sta P_DIR_BUFFER, x
	inx
	ldy P_SEARCH_POS
	lda P_SEARCH_COUNT, y
	sta P_BINBCD_IN
	jsr F_BINBCD_8BIT
	lda P_BINBCD_OUT+1
	jsr F_BCDIFY_BUF
	lda P_BINBCD_OUT+0
	jsr F_BCDIFY_BUF
	
	dex
!loop:
	lda P_DIR_BUFFER, x
	sta $0400+24*40+30, x
	dex
	bpl !loop-
	rts
}
