	.include "drivecode.i"


	.export drv_start

	.export drivebuffer
	.export track_list, sector_list


	.segment "DRIVEBUFFER"

drivebuffer:	.res $100
track_list	= drivebuffer + $80
sector_list	= drivebuffer + $c0


	.segment "DRIVECOMMON"


; ------------------------------------------------------------------------
;
; load file
; args: start track, start sector
; returns: $00 for EOF, $ff for error, $01-$fe for each data block
load:
	jsr recvts

loadchain:
@sendsector:
	jsr drv_readsector
	bcc :+
	lda #$ff		; send read error
	jmp error
:
	ldx #254		; send 254 bytes (full sector)
	lda drivebuffer		; last sector?
	bne :+
	ldx drivebuffer + 1	; send number of bytes in sector (1-254)
	dex
:	stx @buflen
	txa
	jsr drv_send		; send byte count

	ldx #0			; send data
@send:
	lda drivebuffer + 2,x
	jsr drv_send
	inx
@buflen = * + 1
	cpx #$ff
	bne @send

	jsr nextts
	bcc @sendsector
@done:
	lda #0
	jmp senddone


drv_start:
	tsx
	jsr drv_set_exit_sp

drv_main:
	.ifdef LOADERTEST
	ldx #0
:	jsr drv_recv
	sta $0700,x
	inx
	bne :-

:	lda $0700,x
	jsr drv_send
	inx
	bne :-

	jmp drv_main
	.endif

	cli			; allow IRQs when waiting
	jsr drv_recv		; get command byte, exit if ATN goes low
	;sei			; IRQs are now enabled when data is available

	cmp #1			; load a file
	beq load
	cmp #2			; save and replace a file
	beq save
	cmp #'$'		; read directory
	beq directory

	lda #$ff		; unknown command
senddone:
error:
	jsr drv_send
	jmp drv_main


directory:
	jsr drv_get_dir_ts
	jmp loadchain


; ------------------------------------------------------------------------
;
; save and replace file
; args: start track, start sector
; returns: $00 for EOF, $ff for error, $01-$fe for each data block
; reads and sends the first two bytes, receives and overwrites the rest
; file size stays the same
save:
	lda #1
	sta sendflag

	jsr recvts

@receivesector:
	jsr drv_readsector
	bcc :+
@error:
	lda #$ff		; send read error
	jmp error
:
	ldx #254		; receive 254 bytes (full sector)
	lda drivebuffer		; last sector?
	bne :+
	ldx drivebuffer + 1	; send number of bytes in sector (1-254)
	dex
:	stx @buflen
	txa
	jsr drv_send		; send byte count

	lda sendflag		; has load address been sent?
	beq :+

	dec sendflag		; send load address
	lda drivebuffer + 2
	jsr drv_send
	lda drivebuffer + 3
	jsr drv_send
	ldx #2
	bne @receive
:
	ldx #0			; receive data
@receive:
	jsr drv_recv
	sta drivebuffer + 2,x
	inx
@buflen = * + 1
	cpx #$ff
	bne @receive

	jsr drv_writesector	; write back the modified sector
	bcs @error

	jsr nextts
	bcc @receivesector
@done:
	jsr drv_flush		; flush the track cache

	lda #0			; send 0 when we're done
	jmp senddone

sendflag:	.res 1


; receive track and sector args
recvts:
	jsr drv_recv
	tax
	jsr drv_recv
	jmp drv_set_ts


; next t/s in chain
nextts:
	sec
	ldx drivebuffer
	beq :+
	lda drivebuffer + 1
	clc
:	jmp drv_set_ts
