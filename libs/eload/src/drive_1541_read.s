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

.import drv_1541_recv_to_buffer
.import drv_1541_send
.import drv_1541_delay
.import drv_1541_prepare_read
.import drv_1541_search_header
.import drv_1541_restore_orig_job
.import drv_1541_wait_sync


.export drive_code_1541_read
drive_code_1541_read:

; =============================================================================
;
; Drive code assembled to fixed address $0500 follows
;
; =============================================================================
.org $0500
.export drive_code_1541_read_start
drive_code_1541_read_start      = *

loop:
        cli                     ; allow IRQs when waiting
        ldy #4                  ; receive job to buffer (does SEI when rx)
        jsr drv_1541_recv_to_buffer

        ldx buffer              ; job

        dex
        bne @not_rd_sector
        jmp read_sector         ; eload job code: read 1

@not_rd_sector:
ret:
        rts

send_status:
; send the return value from A and two bytes of status
        sta status
        lda #<status
        ldx #>status
        ldy #3
        jmp drv_1541_send


; =============================================================================
;
;
;
; =============================================================================
read_sector:
        lda buffer + 1
        sta job_track_backup
        lda buffer + 2
        sta job_sector_backup

        jsr drv_1541_restore_orig_job
        jsr drv_1541_prepare_read
        jsr drv_1541_search_header
        bcs motor_off_status_ret    ; error: code in A already

        jsr drv_1541_wait_sync
        bcs motor_off_status_ret    ; error: code in A already

        ldy #$bb                    ; write to $1bb
@read1:
        wait_byte_ready
        lda $1c01
        sta $0100, y
        iny
        bne @read1

@read2:
        wait_byte_ready             ; rest of the block
        lda $1c01
        sta buffer, y
        iny
        bne @read2

        lda #ELOAD_OK
        jsr send_status

        lda #<gcr_overflow_buff
        ldx #>gcr_overflow_buff
        ldy #gcr_overflow_size
        jsr drv_1541_send

        iny
        tya                         ; a = low byte = 0, y = 0 = 256 bytes
        ldx #>buffer
        jsr drv_1541_send
        jmp motor_off_ret

motor_off_status_ret:
        jsr send_status
motor_off_ret:
        jsr $f98f               ; prepare motor off (doesn't change C)
        jmp loop

drive_code_1541_read_size  = * - drive_code_1541_read_start
.assert drive_code_1541_read_size <= 256, error, "drive_code_1541_read_size"
.reloc
