	.include "macro.i"
	.include "kernal.i"
	.include "drivetype.i"


	.export loader_init

	.import loader_detect

	.import loader_send, loader_recv
	.import loader_recv_palntsc

        .import drive_code_1541
	;.import drive1571
	;.import drive1581
	;.import drivesd2iec

        .import drive_code_size_1541


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

	.rodata

drive_codes:
        .addr 0
        .addr drive_code_1541
        .addr drive_code_1541           ; 1570
	.addr 0;drive1571
	.addr 0;drive1581
	.addr 0
	.addr 0
	.addr 0
	.addr 0
	.addr 0;drivesd2iec	; sd2iec


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

        lda loader_drivetype
        asl
        tay
        lda drive_codes + 1,y           ; send code for detected drive
        sta code_ptr + 1
        bne :+
        sec                             ; fail if there's no code
        rts
:
        lda drive_codes,y
        sta code_ptr
@codeptrset:

        ldax #drive_code_size_1541      ; todo: be more specific
        stax code_len

        ldax #$0300                     ; where to upload the code to
	stax cmd_addr

        jsr sendcode                    ; upload code

        lda #'E'                       ; execute
        sta cmd_type
        ldax #$0300                    ; where the drivecode starts
        stax cmd_addr
        jsr send_cmd

        ldx #0                         ; delay
:       dex
        bne :-

        clc
        rts

; send code, 32 bytes at a time
.export sendcode
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
:
        lda cmd,x
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
:
	lda $ffff,y
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
	.addr str_sd2iec

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
	.byte "CMD FD - UNSUPPORTED!", 0

str_cmdhd:
	.byte "CMD HD - UNSUPPORTED!", 0

str_ramlink:
	.byte "RAMLINK - UNSUPPORTED!", 0

str_ramdrive:
	.byte "RAMDRIVE - UNSUPPORTED!", 0

str_sd2iec:
	.byte "SD2IEC/UIEC", 0
