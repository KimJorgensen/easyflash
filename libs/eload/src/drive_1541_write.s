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

.include "eload_macros.s"
.include "config.s"
.include "drive_1541_inc.s"

.import drv_1541_prepare_read
.import drv_1541_restore_orig_job
.import drv_1541_recv_to_buffer
.import drv_1541_recv
.import drv_1541_send
.import drv_1541_search_header

.export drive_code_1541_write
drive_code_1541_write  = *

; =============================================================================
;
; Drive code assembled to fixed address $0500 follows
;
; =============================================================================
.org $0500
.export drive_code_1541_write_start
drive_code_1541_write_start      = *

loop:
        cli                     ; allow IRQs when waiting
        ldy #4                  ; receive job to buffer (does SEI when rx)
        jsr drv_1541_recv_to_buffer

        ldx buffer              ; job
        bne write_sector
ret:
        rts                     ; leave overlay code

; =============================================================================
;
; Write a GCR sector to disk. Returns clc if successful, sec if error
;
; =============================================================================
write_sector:
        lda buffer + 1
        sta job_track_backup
        lda buffer + 2
        sta job_sector_backup

        ; receive 69 + 256 bytes of GCR encodec track
        ldy #gcr_overflow_size
        lda #<gcr_overflow_buff
        ldx #>gcr_overflow_buff
        jsr drv_1541_recv            ; 69 bytes
        jsr drv_1541_recv_to_buffer  ; 256 bytes (Y = 0 from prev call)

        ; write
        jsr drv_1541_restore_orig_job
        jsr drv_1541_prepare_read
        jsr drv_1541_search_header

        bcs motor_off_and_ret   ; error: code in A already
        ldx #8                  ; skip 9 bytes after header
@skip9:
        bvc @skip9              ; wait for byte ready
        clv                     ; clear byte ready (V)
        dex
        bpl @skip9
        stx $1c03               ; data port output
        lda $1c0c
        and #$df                ; %111x => %110x
        sta $1c0c               ; write mode

        ; write_sync
        lda #$ff
        ldy #5
        sta $1c01               ; write $ff = sync
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        dey
        bne :-

        ldy #$bb
@write_data_1:
        lda $0100, y
        wait_byte_ready
        sta $1c01               ; write data byte
        iny
        bne @write_data_1

@write_data_2:
        lda buffer, y
        wait_byte_ready
        sta $1c01               ; write data byte
        iny
        bne @write_data_2
        wait_byte_ready
        jsr $fe00               ; head to read mode
        clc                     ; mark for success
motor_off_and_ret:
        pha
        jsr $f98f               ; prepare motor off (doesn't change C)
        lda $1c00
        and #$f7                ; LED off
        sta $1c00
        pla

        bcs :+                  ; C set == error
        lda #ELOAD_OK
:
        ; send the return value from A and two bytes of status
        jsr drv_1541_send
        lda status
        jsr drv_1541_send
        lda status + 1
        jsr drv_1541_send
        jmp loop


drive_code_1541_write_size  = * - drive_code_1541_write_start
.assert drive_code_1541_write_size <= 512, error, "drive_code_1541_write_size"
.reloc
