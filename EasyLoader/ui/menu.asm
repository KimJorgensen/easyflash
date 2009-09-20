.print ">menu.asm"

F_MENU:{

	.const KEEP_CLEAR = 3


	jsr F_INPUT_INIT
main_loop:
	jsr F_INPUT_GETKEY
	beq main_loop

	:if A ; EQ ; #V_KEY_F2 ; JMP ; F_BASIC

	// if no enties -> don't move
	ldx P_NUM_DIR_ENTRIES
	beq main_loop

	:if A ; EQ ; #V_KEY_CUP ; move_up
	:if A ; EQ ; #V_KEY_CDOWN ; move_down
	:if A ; EQ ; #V_KEY_CLEFT ; JMP ; page_up
	:if A ; EQ ; #V_KEY_CRIGHT ; page_down
	:if A ; EQ ; #V_KEY_RETURN ; JSR ; F_LAUNCH // may returns
	:if A ; GE ; #$41 ; ENDIF ; !endif+
		:if A ; LE ; #$5a ; JSR ; F_SEARCH_KEY
	!endif:
	:if A ; EQ ; #V_KEY_DEL ; JSR ; F_SEARCH_DEL
	:if A ; EQ ; #$5f ; JSR ; F_SEARCH_RESET
	jmp main_loop

move_up:
	dec P_DRAW_OFFSET
	jmp draw_screen

move_down:
	inc P_DRAW_OFFSET
	jmp draw_screen

page_up:
	:sub P_DRAW_OFFSET ; #23
	jmp draw_screen

page_down:
	:add P_DRAW_OFFSET ; #23
//	jmp draw_screen

draw_screen:
	jsr F_DRAW
	jmp main_loop


}