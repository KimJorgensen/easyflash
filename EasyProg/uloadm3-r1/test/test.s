	.include "macro.i"


	.import loader_init
	.import loader_open
	.import loader_read, loader_write

	.import init_decruncher
	.import get_decrunched_byte
	.export get_crunched_byte

	.import music_init
	.import music_play


dir_buf 	= $0428


	.segment "STARTUP"

	.word basicstub

basicstub:
	.word @nextline
	.word 2006
	.byte $9e
	.byte <(((init / 1000) .mod 10) + $30)
	.byte <(((init / 100 ) .mod 10) + $30)
	.byte <(((init / 10  ) .mod 10) + $30)
	.byte <(((init       ) .mod 10) + $30)
	.byte 0
@nextline:
	.word 0


init:
	lda #$0b
	sta $d020
	sta $d021

	ldx #0
:	lda #$20
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $0700,x
	lda #7
	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $db00,x
	lda #$1b
	sta $6000,x
	sta $6100,x
	sta $6200,x
	sta $6300,x
	inx
	bne :-

	jsr music_init

	jsr loader_init
	bcs error
	
	lda #$7f
	sta $dc0d
	lda #$35
	sta $01
	
	ldax #irq
	stax $fffe
	lda #$1b
	sta $d011
	lda #$ff
	sta $d012
	lda #1
	sta $d01a
	
	jsr scan_files
	
	jmp main


; scan directory and save start track/sector for each file
scan_files:
	lda #'$'			; read directory
	jsr loader_open
	bcs error

@read_dir_block:
	ldx #2
@read:
	jsr loader_read
	bcc :+
	rts
:
	sta dir_buf,x
	inx
	bne @read

	ldx #0
@check_entry:
	lda dir_buf + 2,x
	cmp #$82
	bne @skip

	lda dir_buf + 5,x
	cmp #$30
	bcc @skip
	cmp #$3a
	bcs @skip
	and #$0f
	tay
	lda dir_buf + 3,x
	sta file_track,y
	lda dir_buf + 4,x
	sta file_sector,y
	
@skip:
	txa
	clc
	adc #$20
	bcs @read_dir_block
	tax
	bcc @check_entry


file_track:
	.res 10

file_sector:
	.res 10


error:
	lda #2
:	sta $d020
	eor #8
	.byte 2
	jmp :-


main:
	lda $dd00
	and #$fc
	ora #2
	sta $dd00
	lda #$3b
	sta $d011
	lda #$80
	sta $d018

@first:
	lda #0
	sta imgnum
@load:
	ldx imgnum
	ldy file_sector,x
	lda file_track,x
	tax
	lda #1
	jsr loader_open
	bcs error
	
;	jsr loader_read
;	bcs error
;	sta @addr
;	jsr loader_read
;	bcs error
;	sta @addr + 1
;@read:
;	jsr loader_read
;	bcs @eof
	
	jsr init_decruncher
	jsr get_decrunched_byte
	;bcs error
	sta @addr
	jsr get_decrunched_byte
	;bcs error
	sta @addr + 1
@read:
	jsr get_decrunched_byte
	bcs @eof
	
@addr = * + 1
	sta $5e1f
	inc @addr
	bne @read
	inc @addr + 1
	bne @read
@eof:
	jsr loader_read
	bcc @eof
	inc imgnum
	lda imgnum
	cmp #10
	bcc @load
	bcs @first


imgnum:	.res 1

	.res 20


get_crunched_byte:
	php
	sty @gcb_y
	stx @gcb_x
	jsr loader_read
@gcb_x = * + 1
	ldx #$5e
@gcb_y = * + 1
	ldy #$1f
	plp
	rts


irq:
	inc $d020
	pha
	txa
	pha
	tya
	pha
	
	jsr music_play
	lda #$ff
	sta $d019
	
	pla
	tay
	pla
	tax
	pla
	dec $d020
	rti
