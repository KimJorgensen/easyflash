
        .include "kernal.i"

        .importzp       sp, sreg, regsave
        .importzp       ptr1, ptr2, ptr3, ptr4
        .importzp       tmp1, tmp2, tmp3, tmp4

        .import loader_init

; loader_open is used to open a file for reading or writing
	.export loader_open

; loader_exit is used to cancel the drive code
	.export loader_exit

; loader_read and loader_write are used for loading from or saving to a file
	.export loader_read

; loader_send and loader_recv are for communicating with the drive
	.export loader_send, loader_recv

; this export is used by loader_init to adjust the code for NTSC
	.export loader_recv_palntsc


; A = $01 for load, X = track, Y = sector, sec on error
;    after open, call loader_read until sec
; A = $02 for save, X = track, Y = sector, sec on error
;    after open, call loader_read twice to read load address, then loader_write until sec
; A = $24 for load directory, X/Y = don't care, sec on error
;    after open, call loader_read until sec as a normal file
loader_open:
        sta ptr1
        stx ptr1 + 1
        lda $ba                         ; set drive to listen
        jsr LISTEN
        lda #$60                        ; channel 0
        jsr SECOND
        lda #0
        sta tmp1
@send_name:
        ldy tmp1
        lda (ptr1),y
        beq @end_name                   ; 0-termination
        jsr CIOUT
        inc tmp1
        bne @send_name                  ; branch always (usually)
@end_name:
        jsr UNLSN

        ; todo: Fehler checken!

        jsr loader_init

        lda #1                          ; load
        jsr loader_send

        jsr loader_recv

	cmp #$ff
	bne @ok
	sec
	rts
@ok:
	sta loader_ctr
	clc
	rts


; buffer counter
loader_ctr:	.res 1


; cancel drive code
loader_exit:
	lda $dd00
	ora #$08
	sta $dd00
	ldx #0
:	dex
	bne :-
	and #$07
	sta $dd00
	rts


; read a byte from a file, sec on eof or error
loader_read:
	lda loader_ctr
	beq @nextblock
@return:
	dec loader_ctr
	jsr loader_recv
	clc
@error:
@eof:
	rts
@nextblock:
	jsr loader_recv
	sec
	beq @eof
	cmp #$ff
	beq @error
	sta loader_ctr
	jmp @return


; send a byte to the drive
loader_send:
	sta loader_send_savea
loader_send_do:
	sty loader_send_savey

	pha
	lsr
	lsr
	lsr
	lsr
	tay

	lda $dd00
	and #7
	sta $dd00
	sta savedd00
	eor #$07
	ora #$38
	sta $dd02

@waitdrv:
	bit $dd00		; wait for drive to signal ready to receive
	bvs @waitdrv		; with CLK low

	lda $dd00		; pull DATA low to acknowledge
	ora #$20
	sta $dd00

@wait2:
	bit $dd00		; wait for drive to release CLK
	bvc @wait2

	sei

loader_send_waitbadline:
	lda $d011		; wait until a badline won't screw up
	clc			; the timing
	sbc $d012
	and #7
	beq loader_send_waitbadline
loader_send_nobadline:

	lda $dd00		; release DATA to signal that data is coming
	;ora #$20
	and #$df
	sta $dd00

	lda sendtab,y		; send the first two bits
	sta $dd00

	lsr
	lsr
	and #%00110000		; send the next two
	sta $dd00

	pla			; get the next nybble
	and #$0f
	tay
	lda sendtab,y
	sta $dd00

	lsr			; send the last two bits
	lsr
	and #%00110000
	sta $dd00

	nop			; slight delay, and...
	nop
	lda savedd00		; restore $dd00 and $dd02
	sta $dd00
	lda #$3f
	sta $dd02

	ldy loader_send_savey
	lda loader_send_savea

	cli
	rts

savedd00:		.res 1
loader_send_savea:	.res 1
loader_send_savey:	.res 1


sendtab:
	.byte $00, $80, $20, $a0
	.byte $40, $c0, $60, $e0
	.byte $10, $90, $30, $b0
	.byte $50, $d0, $70, $f0
sendtab_end:
	.assert >sendtab_end = >sendtab, error, "sendtab mustn't cross page boundary"


; receive a byte from the drive
loader_recv:
:	bit $dd00		; wait for drive to signal data ready with
	bmi :-			; DATA low

loader_recv_do:
	lda $dd00		; drop CLK to acknowledge
	ora #$10
	sta $dd00

@wait2:
	bit $dd00		; wait for drive to release DATA
	bpl @wait2

	sei

loader_recv_waitbadline:
	lda $d011		; wait until a badline won't screw up
	clc			; the timing
	sbc $d012
	and #7
	beq loader_recv_waitbadline
loader_recv_nobadline:

	lda $dd00
	;ora #$10
	and #$ef
	sta $dd00		; set CLK low to signal that we are receiving
loader_recv_palntsc:
	beq :+			; 2 cycles for PAL, 3 for NTSC
:	nop

	and #3
	sta @eor+1
	sta $dd00		; set CLK high to be able to read the
	lda $dd00		; bits the diskdrive sends
	lsr
	lsr
	eor $dd00
	lsr
	lsr
	eor $dd00
	lsr
	lsr
@eor:
	eor #$00
	eor $dd00
	cli
	rts

	.import sendcode
        jsr sendcode

