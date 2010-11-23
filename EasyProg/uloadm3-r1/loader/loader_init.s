	.include "macro.i"
	.include "kernal.i"
	.include "drivetype.i"


	.export loader_init

	.import loader_detect

	.import loader_send, loader_recv
	.import loader_recv_palntsc

 .ifdef UL3_SUPERCPUFIX
	.import supercpu_send, supercpu_recv
 .endif

 .ifdef UL3_DTV2FIX
	.import dtv2_send, dtv2_recv
	.import loader_send_waitbadline, loader_recv_waitbadline
	.import loader_send_nobadline, loader_recv_nobadline
 .endif

	.import __DRIVECOMMON_RUN__
	.import __DRIVECOMMON_SIZE__
	.import __DRIVECOMMON_LOAD__

	.import drv_start

	.import __DRIVESPECIFIC_START__
	.import __DRIVESPECIFIC_SIZE__

	.import drive1541
	.import drive1571
	.import drive1581
	.import drivecmdfd
	.import drivecmdhd


cmdbytes	= 32			; number of bytes in one M-W command


	.bss

code_len:		.res 2
cmd_data:		.res 1
loader_drivetype:	.res 1


	.data

cmd:		.byte "M-"
cmd_type:	.byte "W"
cmd_addr:	.addr $ffff
cmd_len:	.byte 0

u0m1:		.byte "U0>M1"


	.rodata

drivecodes:
	.addr 0
	.addr drive1541
	.addr drive1541		; 1570
	.addr drive1571
	.addr drive1581
	.addr drivecmdfd
	.addr drivecmdhd
	.addr 0
	.addr 0


	.code

; initialize loader by sending over drive code
loader_init:
	lda $ba				; default to device 8
	bne :+
	lda #8
	sta $ba
:
	;lda #1				; prepare detection messages
	;sta $0286
	ldx #24
	ldy #0
	clc
	jsr PLOT

	ldax #str_uload
	jsr strout
	
	sei				; detect PAL or NTSC

	lda #$ff			; wait for line 255
:	cmp $d012
	bne :-

	lda #8				; wait for line 263
:	cmp $d012			; ntsc hits line 8 instead
	bne :-

	bit $d011			; msb set = pal
	bmi @pal
@ntsc:
	lda #$d0			; BNE = 3 cycles
	sta loader_recv_palntsc
	ldax #str_ntsc
	jmp @pal_ntsc_set
@pal:
	;lda #$f0			; BEQ = 2 cycles
	;sta loader_recv_palntsc
	ldax #str_pal
@pal_ntsc_set:
	cli

	jsr strout

 .ifdef UL3_DTV2FIX
	jsr dtv2_detect			; detect dtv2
	ldax #str_dtv2
	bcs @gotmodel
 .endif

	ldy #0				; check for signs of C128

	lda $d030
	cmp #$ff
	beq :+
	iny
:
	lda $d600
	beq :+
	iny
:
	ldax #str_c64
	cpy #0
	beq :+
	ldax #str_c128
:
@gotmodel:
	jsr strout

 .ifdef UL3_SUPERCPUFIX
	bit $d0bc			; detect SuperCPU
	bmi :+
	jsr supercpu
:
 .endif

	ldax #str_dev			; print device number
	jsr strout

	ldx #$ff
	lda $ba
:	inx
	sec
	sbc #10
	bcs :-
	clc
	adc #10
	pha
	txa
	beq :+
	ora #$30
	jsr $ffd2
:	pla
	ora #$30
	jsr $ffd2	

	lda #' '
	jsr $ffd2

	jsr loader_detect		; detect what kind of drive we loaded from
	bcc :+
	rts
:	sta loader_drivetype
	asl
	tay
	lda str_drive + 1,y
	tax
	lda str_drive,y
	jsr strout

	ldax #__DRIVECOMMON_LOAD__	; send common drive code
	stax code_ptr

	ldax #__DRIVECOMMON_SIZE__
	stax code_len

	ldax #__DRIVECOMMON_RUN__
	stax cmd_addr

	jsr sendcode			; upload code

	jsr check1571disk		; check if 1571 disk is double sided
	bcc @codeptrset

	lda loader_drivetype
	asl
	tay
	lda drivecodes + 1,y		; send code for detected drive
	sta code_ptr + 1
	bne :+
	sec				; fail if there's no code
	rts
:	lda drivecodes,y
	sta code_ptr
@codeptrset:

	ldax #__DRIVESPECIFIC_SIZE__
	stax code_len

	ldax #__DRIVESPECIFIC_START__	; they all start at the same address
	stax cmd_addr

	jsr sendcode			; upload code

	lda #'E'			; execute
	sta cmd_type
	ldax #drv_start
	stax cmd_addr
	jsr send_cmd

	ldx #0				; delay
:	dex
	bne :-

	clc
	rts


 .ifdef UL3_SUPERCPUFIX

supercpu:
	ldax #str_scpu
	jsr strout

	lda #'1'
	bit $d0b0
	bmi :+
	lda #'2'
:	jsr $ffd2

	lda #$4c			; redirect to supercpu routines
	sta loader_send
	sta loader_recv
	ldax #supercpu_send
	stax loader_send + 1
	ldax #supercpu_recv
	stax loader_recv + 1

	rts

.endif


 .ifdef UL3_DTV2FIX

; detect DTV2 by checking VIC mirror regs
dtv2_detect:
	lda $d000
	pha
	lda #1
	sta $d03f
	lda #$55
	sta $d000
	cmp $d040
	bne @dtv2
	lda #$aa
	sta $d000
	cmp $d040
	bne @dtv2
@c64:
	pla
	sta $d000
	clc
	rts
@dtv2:
	pla
	sta $d000

	lda #$4c			; redirect to dtv2 routines
	sta loader_send
	sta loader_recv
	ldax #dtv2_send
	stax loader_send + 1
	ldax #dtv2_recv
	stax loader_recv + 1

	lda #$20			; disable vic badlines
	sta $d03c

	lda #$4c			; disable loader badline checks
	sta loader_send_waitbadline
	sta loader_recv_waitbadline
	ldax #loader_send_nobadline
	stax loader_send_waitbadline + 1
	ldax #loader_recv_nobadline
	stax loader_recv_waitbadline + 1

	sec
	rts

 .endif


; check if d71 or d64 is in 1571 drive
check1571disk:
	lda loader_drivetype
	cmp #drivetype_1571
	beq :+
	rts
:
	lda #18				; track 18
	ldx #$0c
	ldy #$00
	jsr drivepoke

	lda #0				; sector 0
	ldx #$0d
	ldy #$00
	jsr drivepoke

	lda #$80			; read sector job code
	ldx #$03
	ldy #$00
	jsr drivepoke

:	jsr drivepeek			; wait for job status
	bmi :-

	beq @gotsector
	cmp #1
	beq @gotsector
	sec
	rts

@gotsector:
	ldx #$03			; read 4th byte
	ldy #$06
	jsr drivepeek

	bmi @doublesided		; $80 means we have a double sided 1571 disk

	ldax #drive1541			; no, send 1541 code instead
	stax code_ptr
	clc
	rts


@doublesided:
	lda $ba				; set drive to listen
	jsr LISTEN
	lda #$6f			; channel 15
	jsr SECOND

	ldx #0				; send U0>M1 to switch to 1571 mode
:	lda u0m1,x
	jsr CIOUT
	inx
	cpx #5
	bne :-

	jsr UNLSN
	sec
	rts


drivepoke:
	stx cmd_addr
	sty cmd_addr + 1
	sta cmd_data

	lda #'W'
	sta cmd_type
	lda #1
	sta cmd_len
	ldax #cmd_data
	stax code_ptr
	jsr send_cmd

	ldx cmd_addr
	ldy cmd_addr + 1
	lda cmd_data

	rts


drivepeek:
	stx cmd_addr
	sty cmd_addr + 1
	sta cmd_data

	lda #'R'
	sta cmd_type
	lda #1
	sta cmd_len
	ldax #cmd_data
	stax code_ptr
	jsr send_cmd

	lda $ba
	jsr TALK
	lda #$6f
	jsr TKSA
	jsr ACPTR
	pha
	jsr UNTLK

	ldx cmd_addr
	ldy cmd_addr + 1
	pla

	rts


; send code, 32 bytes at a time
sendcode:
	lda #'W'			; M-W
	sta cmd_type
@next:
	lda #cmdbytes			; at least 32 bytes left?
	sta cmd_len
	lda code_len + 1
	bne @send
	lda code_len
	cmp #cmdbytes
	bcs @send
	beq @done
	sta cmd_len			; no, just send the rest
@send:
	jsr send_cmd			; send M-W command

	ldax cmd_addr
	jsr addlen
	stax cmd_addr

	ldax code_ptr
	jsr addlen
	stax code_ptr

	lda code_len
	sec
	sbc cmd_len
	sta code_len
	bcs :+
	dec code_len + 1
:	ora code_len + 1
	bne @next
@done:
	rts


addlen:
	clc
	adc cmd_len
	bcc :+
	inx
:	rts


send_cmd:
	lda $ba				; set drive to listen
	jsr LISTEN
	lda #$6f			; channel 15
	jsr SECOND

	ldx #0				; send M-W or M-E command and address
:	lda cmd,x
	jsr CIOUT
	inx
	cpx #5
	bne :-

	lda cmd_type			; exec
	cmp #'E'
	beq send_cmd_done

	lda cmd_len			; length of data
	jsr CIOUT

	lda cmd_type			; read
	cmp #'R'
	beq send_cmd_done

	ldy #0				; send the data
code_ptr = * + 1
:	lda $5e1f,y
	jsr CIOUT
	iny
	cpy cmd_len
	bne :-
send_cmd_done:
	jmp UNLSN			; unlisten executes the command


strout:
	stax @ptr
@ptr = * + 1
:	lda $5e1f
	beq @done
	jsr $ffd2
	inc @ptr
	bne :-
	inc @ptr + 1
	bne :-
@done:
	rts


	.rodata

str_uload:
	.byte "ULOAD M3 ", 0

str_pal:
	.byte "PAL", 0

str_ntsc:
	.byte "NTSC", 0

str_c64:
	.byte " C64", 0

str_c128:
	.byte " C128", 0

 .ifdef UL3_DTV2FIX
str_dtv2:
	.byte " DTV2", 0
 .endif

 .ifdef UL3_SUPERCPUFIX
str_scpu:
	.byte " SUPERCPU V", 0
 .endif

str_dev:
	.byte " #", 0

str_drive:
	.addr str_unknown
	.addr str_1541
	.addr str_1570
	.addr str_1571
	.addr str_1581
	.addr str_cmdfd
	.addr str_cmdhd
	.addr str_ramlink
	.addr str_ramdrive

str_unknown:
	.byte "UNKNOWN DRIVE!", 0

str_1541:
	.byte "1541", 0

str_1570:
	.byte "1570", 0

str_1571:
	.byte "1571", 0

str_1581:
	.byte "1581", 0

str_cmdfd:
	.byte "CMD FD", 0

str_cmdhd:
	.byte "CMD HD", 0

str_ramlink:
	.byte "RAMLINK - UNSUPPORTED!", 0

str_ramdrive:
	.byte "RAMDRIVE - UNSUPPORTED!", 0
