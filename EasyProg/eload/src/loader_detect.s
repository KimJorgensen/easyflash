; drive type detection
; based on DreamLoad sources by Ninja & DocBacardi


	.include "macro.i"
	.include "kernal.i"
	.include "drivetype.i"

    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

	.export loader_detect


sendsecond	= $f3d5		; send secondary address
closecurr	= $f642		; close


	.bss

mlo:	.res 1
mhi:	.res 2

	.rodata

magic_family:
	.byte $43, $0d, $ff

magic_addr:
	.addr $fea4, $e5c6, $a6e9

magic_lo:
        .byte "4778FH"
magic_hi:
        .byte $b1, $b0, $b1, $b1, "DD"

str_mr:
        .byte "M-R"
str_mr_addr:
        .addr $fea0
str_mr_nbytes:
	.byte $01
str_mr_len = * - str_mr

str_ui:
        .byte "UI"
str_ui_len = * - str_ui

; this string is used to check for "SD2IEC"
; and the substring "IEC" is used to check for "UIEC"
str_d2iec:
	.byte "D2IEC"
str_d2iec_len = * - str_d2iec

	.code

loader_detect:
	; ask the drive to send its ID
	lda #str_ui_len		; set name to M-R command string
	ldx #<str_ui
	ldy #>str_ui
	jsr send_command
	bcs fail
	; search for "UIEC" or "SD2IEC" in the string
@sd2iec_start:
	jsr getbyte
	bcs @not_sd2iec
	cmp #'U'
	beq @check_uiec
	cmp #'S'
	bne @sd2iec_start
	ldx #0
	beq @check_d2iec
@check_uiec:
	ldx #3			; seach for "IEC"
@check_d2iec:
	stx tmp1		; index of next character to be checked
	; now check the remaining chars of "SD2IEC"
	jsr getbyte
	bcs @not_sd2iec
	ldx tmp1
	sta $0400, x
	cmp str_d2iec, x
	bne @sd2iec_start
	inx
	cpx #str_d2iec_len
	bne @check_d2iec
	; match!
	jsr close_command
	lda #drivetype_sd2iec
	clc
	rts

@not_sd2iec:
	jsr close_command

	ldax #$fea0		; read $fea0 to get drive family
	stax str_mr_addr
	lda #1
	sta str_mr_nbytes

	jsr send_mr		; send M-R command
	bcs fail

	jsr getbyte		; get the byte
	;sta $0428
	pha
	jsr close_command
	pla

	ldx #2			; compare magic bytes
:	cmp magic_family,x
	beq foundfamily
	dex
	bpl :-
	sec

fail:
	rts


foundfamily:
	;stx $0429

	txa
	asl
	tax

	lda magic_addr,x	; read family address to get model
	sta str_mr_addr
	lda magic_addr + 1,x
	sta str_mr_addr + 1
	lda #2
	sta str_mr_nbytes

	jsr send_mr		; send M-R command
	bcs fail

	jsr getbyte		; get magic bytes
	sta mlo
	;sta $042a
	jsr getbyte
	;sta $042b
	sta mhi

	jsr close_command

	ldx #6			; compare magic bytes
@compare:
	lda magic_lo - 1,x
	cmp mlo
	bne :+
	lda magic_hi - 1,x
	cmp mhi
	beq @found
:	dex
	bne @compare
@found:
	;stx $042c

	txa			; return model in A
	clc
	rts


send_mr:
	lda #str_mr_len		; set name to M-R command string
	ldx #<str_mr
	ldy #>str_mr
send_command:
	jsr SETNAM

	lda #$6f		; set secondary address
	sta $b9

	jsr sendsecond		; send command, carry set on fail
	rts


close_command:
	jsr UNTLK
	jmp closecurr


; read a byte from the current IEC drive and return it in A.
; In case of an error return C set.
getbyte:
	lda #0
	sta $90

	lda $ba
	jsr TALK
	lda #$6f
	jsr TKSA
	jsr ACPTR	; clears C
	ldx $90
	beq @rts
	sec
@rts:
	rts
