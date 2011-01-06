	.include "macro.i"
	.include "kernal.i"
	.include "drivetype.i"


.export loader_upload_code

.import drive_detect
.import loader_send, loader_recv

.import drive_code_1541
.import drive_code_1571
.import drive_code_1581
.import drive_code_sd2iec

.import drive_code_size_1541
.import drive_code_size_1571
.import drive_code_size_1581
.import drive_code_size_sd2iec


cmdbytes        = 32   ; number of bytes in one M-W command


	.bss

code_len:		.res 2
cmd_data:		.res 1

        .export loader_drivetype
loader_drivetype:	.res 1


.data

cmd:            .byte "M-"
cmd_type:       .byte "W"
cmd_addr:       .addr $ffff
cmd_len:        .byte 0

.rodata

drive_codes:
        .addr 0
        .addr drive_code_1541
        .addr drive_code_1541           ; 1570
        .addr drive_code_1571
        .addr drive_code_1581
        .addr 0
        .addr 0
        .addr drive_code_sd2iec         ; sd2iec
        .addr 0

drive_code_sizes:
        .addr 0
        .addr drive_code_size_1541
        .addr drive_code_size_1541      ; 1570
        .addr drive_code_size_1571
        .addr drive_code_size_1581
        .addr 0
        .addr 0
        .addr drive_code_size_sd2iec    ; sd2iec
        .addr 0

.code

; =============================================================================
;
; Set the device number for the drive to be used and check its type.
; The drive number is stored in $BA. Return the drive type.
;
; int __fastcall__ eload_set_drive_check_fastload(uint8_t dev);
;
; parameters:
;       drive number in A (X is ignored)
;
; return:
;       drive type in AX (A = low)
;
; =============================================================================
.export _eload_set_drive_check_fastload
_eload_set_drive_check_fastload:
        sta $ba
        jsr drive_detect
        sta loader_drivetype
        ldx #0
        rts

; =============================================================================
;
; Set the device number for the drive to be used and set its type to "unknown".
; This disables the fast loader. The drive number is stored in $BA.
;
; void __fastcall__ eload_set_drive_disable_fastload(uint8_t dev);
;
; parameters:
;       drive number in A (X is ignored)
;
; return:
;       -
;
; =============================================================================
.export _eload_set_drive_disable_fastload
_eload_set_drive_disable_fastload:
        sta $ba
        lda #drivetype_unknown
        sta loader_drivetype
        rts

; =============================================================================
;
; Check if the current drive is accelerated.
;
; int eload_drive_is_fast(void);
;
; Return:
;       Result in AX.
;       0       Drive not accelerated (eload uses Kernal calls)
;       >0      Drive has a fast loader
;       Zero flag is set according to the result.
;
; Changes:
;       A, X, flags
;
; =============================================================================
.export _eload_drive_is_fast
_eload_drive_is_fast:
        ldx loader_drivetype
        lda drive_codes + 1,x
        tax
        rts


; =============================================================================
;
; Upload the drive code if this drive is supported.
;
; Return:
;       C clear if the drive code has been uploaded
;       C set if the drive is not supported (i.e. must use Kernal)
;
; =============================================================================
.export loader_upload_code
loader_upload_code:
        lda loader_drivetype
        asl
        tay
        lda drive_codes + 1, y          ; send code for detected drive
        sta code_ptr + 1
        bne :+
        sec                             ; fail if there's no code
        rts
:
        lda drive_codes, y
        sta code_ptr

        lda drive_code_sizes + 1, y
        sta code_len + 1
        lda drive_code_sizes, y
        sta code_len

        ldax #$0300                     ; where to upload the code to
        stax cmd_addr

        jsr sendcode                    ; upload code

        lda #'E'                        ; execute
        sta cmd_type
        ldax #$0300                     ; where the drivecode starts
        stax cmd_addr
        jsr send_cmd

        ldx #0                          ; delay
:       dex
        bne :-

        clc
        rts

; =============================================================================
;
; send code, 32 bytes at a time
;
; =============================================================================
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
:
        rts


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


