 ;
 ; ELoad
 ;
 ; (c) 2011 Thomas Giesel
 ;
 ; This software is provided 'as-is', without any express or implied
 ; warranty.  In no event will the authors be held liable for any damages
 ; arising from the use of this software.
 ;
 ; Permission is granted to anyone to use this software for any purpose,
 ; including commercial applications, and to alter it and redistribute it
 ; freely, subject to the following restrictions:
 ;
 ; 1. The origin of this software must not be misrepresented; you must not
 ;    claim that you wrote the original software. If you use this software
 ;    in a product, an acknowledgment in the product documentation would be
 ;    appreciated but is not required.
 ; 2. Altered source versions must be plainly marked as such, and must not be
 ;    misrepresented as being the original software.
 ; 3. This notice may not be removed or altered from any source distribution.
 ;
 ; Thomas Giesel skoe@directbox.com
 ;

.include "kernal.s"
.include "drivetype.s"

.importzp       ptr1, ptr2, ptr3, ptr4
.importzp       tmp1, tmp2, tmp3, tmp4

.import eload_dos_open_listen_cmd
.import eload_dos_send_data
.import eload_dos_unlisten_close


.export _eload_prepare_drive

.import drive_detect
.import eload_send_nodma

.import drv_start

.import drive_code_1541
;.import drive_code_1571
;.import drive_code_1581
.import drive_code_sd2iec

.import drive_code_init_size_1541
;.import drive_code_size_1571
;.import drive_code_size_1581
.import drive_code_init_size_sd2iec


code_ptr        = ptr1
code_len        = ptr2

cmdbytes        = 32   ; number of bytes in one M-W command


.bss

.export eload_dev
eload_dev:
        .res 1

drivetype:
        .res 1
cmd_addr:
        .res 2
cmd_len:
        .res 1

.rodata

str_mw:
        .byte "m-w"
str_mw_len = * - str_mw

str_me:
        .byte "m-e"
        .word $0300
str_me_len = * - str_me

drive_codes:
        .addr 0
        .addr 0
        .addr drive_code_1541
        .addr drive_code_1541           ; 1570
        .addr drive_code_1541           ; for now
        .addr 0; drive_code_1581
        .addr 0
        .addr 0
        .addr drive_code_sd2iec         ; sd2iec
        .addr 0

drive_code_init_sizes:
        .byte 0
        .byte 0
        .byte <drive_code_init_size_1541
        .byte <drive_code_init_size_1541     ; 1570
        .byte <drive_code_init_size_1541     ; for now
        .byte 0 ;<drive_code_size_1581
        .byte 0
        .byte 0
        .byte <drive_code_init_size_sd2iec   ; sd2iec
        .byte 0

.code

; =============================================================================
;
; Refer to eload.h for documentation.
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
        sta eload_dev
        jsr drive_detect
        sta drivetype
        ldx #0
        rts

; =============================================================================
;
; Refer to eload.h for documentation.
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
        sta eload_dev
        lda #drivetype_unknown
        sta drivetype
        rts

; =============================================================================
;
; Refer to eload.h for documentation.
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
        ldx drivetype
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
.export _eload_prepare_drive
_eload_prepare_drive:
        jsr set_code_ptr_code_size
        lda #<$0300                     ; where to upload the code to
        sta cmd_addr
        lda #>$0300
        sta cmd_addr + 1

        jsr send_code
        jsr start_code

        ; no final drive code needed for sd2iec
        lda drivetype
        cmp #drivetype_sd2iec
        beq @no_drive_code

        ; upload the full drive code using the fast protocol
        jsr set_code_ptr_code_size
        lda #4                          ; number of blocks to transfer
        sta tmp1
        sei
:
        lda code_ptr
        ldx code_ptr + 1
        ldy #0
        jsr eload_send_nodma
        inc code_ptr + 1
        dec tmp1
        bne :-
        cli

@no_drive_code:
        clc
        rts

set_code_ptr_code_size:
        lda drivetype
        asl
        tay
        lda drive_codes + 1, y          ; ptr to send_code for detected drive
        sta code_ptr + 1
        bne :+
        sec                             ; fail if there's no code
        rts
:
        lda drive_codes, y
        sta code_ptr

        ldy drivetype
        lda drive_code_init_sizes, y
        sta code_len
        rts

; =============================================================================
;
; Send code, 32 bytes at a time
;
; =============================================================================
send_code:
@next:
        lda #cmdbytes       ; at least 32 bytes left?
        sta cmd_len
        lda code_len
        cmp #cmdbytes
        bcs @send
        beq done
        sta cmd_len         ; no, just send the rest
@send:
        jsr eload_dos_open_listen_cmd
        bcs done

        lda #str_mw_len
        ldx #<str_mw
        ldy #>str_mw
        jsr eload_dos_send_data

        lda #3
        ldx #<cmd_addr
        ldy #>cmd_addr
        jsr eload_dos_send_data

        lda cmd_len
        ldx code_ptr
        ldy code_ptr + 1
        jsr eload_dos_send_data
        jsr UNLSN

        lda cmd_addr
        ldx cmd_addr + 1
        jsr addlen
        sta cmd_addr
        stx cmd_addr + 1

        lda code_ptr
        ldx code_ptr + 1
        jsr addlen
        sta code_ptr
        stx code_ptr + 1

        lda code_len
        sec
        sbc cmd_len
        sta code_len
        bne @next
done:
        rts


addlen:
        clc
        adc #cmdbytes
        bcc :+
        inx
:
        rts

; =============================================================================
;
; Send M-E $0300
;
; =============================================================================
start_code:
        jsr eload_dos_open_listen_cmd
        bcs done
        lda #str_me_len
        ldx #<str_me
        ldy #>str_me
        jsr eload_dos_send_data
        jsr UNLSN

        ldy #10                 ; delay
:       dex
        bne :-
        dey
        bne :-
        rts
