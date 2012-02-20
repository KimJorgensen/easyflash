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
.import drv_1541_set_ts_backup
.import drv_1541_restore_orig_job
.import drv_1541_exec_this_job
.import drv_1541_recv_to_buffer
.import drv_1541_recv
.import drv_1541_send
.import drv_1541_wait_sync
.import drv_1541_move_head
.import drv_1541_move_head_direct
.import drv_1541_update_disk_info

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
        ldy #3                  ; receive job to buffer (does SEI when rx)
        jsr drv_1541_recv_to_buffer

        lda buffer              ; job

        cmp #1
        bne @not_wr_sector

        ldx buffer + 1
        lda buffer + 2
        jsr drv_1541_set_ts_backup
        jmp write_sector

@not_wr_sector:

        cmp #2
        bne @not_format
        jmp format_disk

@not_format:
ret:
        rts

; =============================================================================
;
; Write a GCR sector to disk. Returns clc if successful, sec if error
; T/S have been set using drv_1541_set_ts_backup
;
; =============================================================================
write_sector:
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

        bcs @ret                ; error: code in A already
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

        ; todo: gap too large?!
        jsr write_sync

        ldy #$bb
@write_data_1:
        lda $0100, y
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        sta $1c01               ; write data byte
        iny
        bne @write_data_1

@write_data_2:
        lda buffer, y
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        sta $1c01               ; write data byte
        iny
        bne @write_data_2
:
        bvc :-                  ; wait for byte ready (last byte)
        jsr $fe00               ; head to read mode
        clc                     ; mark for success
@ret:
        pha
        jsr $f98f               ; prepare motor off (doesn't change C)
        pla

        bcs :+
        lda #ELOAD_OK
:
send_and_loop:
        jsr drv_1541_send       ; send OK or error
        jmp loop


; =============================================================================
;
;
; =============================================================================

format_disk:
        ; switch on motor, set bitrate for track 1, bump
        lda #1
        sta current_track       ; we'll be on track 1
        jsr drv_1541_prepare_read
        lda #256 - 90           ; 90 / 2 = 45 tracks
        jsr drv_1541_move_head_direct

        jsr $fe0e               ; Write $55 10240 times
        jsr write_sync          ; and sync
        jsr $fe00               ; head to read mode

        ; count bytes per track, should be about 7692 on track 1
        ldy #5                  ; start at overhead of this code
        ldx #0                  ; instead of 0
@count:
        nop                     ;  2   loop with 26 cycles = 1 byte
        jsr ret                 ; 12   to waste cylces
        iny                     ;  2   inc low byte of counter
        bne :+                  ;  3
        inx                     ;      inc high byte of counter
        beq @timeout
:
        bit $1c00               ;  4   sync found?
        bmi @count              ;  3   no => wait and count
        clv                     ; clear byte ready (V)
        sty job_track           ; tmp use: bytes low
        lda #ELOAD_OK
        bvc @send
@timeout:
        lda #ELOAD_ERR_NO_SYNC
@send:
        jsr drv_1541_send       ; send OK or error
        lda job_track
        jsr drv_1541_send       ; bytes per track low
        txa
        jmp send_and_loop       ; bytes per track high


; =============================================================================
;
; ; wait for the header for job_track/job_sector
;
; parameters:
;       -
;
; return:
;
; changes:
;
; =============================================================================
.export drv_1541_search_header
drv_1541_search_header:
        jsr drv_1541_move_head
        lda #2                  ; retry counter for track correction
        sta retry_sh_cnt
@retry_new_track:
        jsr drv_1541_prepare_read
        lda iddrv0              ; collect header data
        sta header_id
        lda iddrv0 + 1
        sta header_id + 1
        lda job_track
        sta header_track
        lda job_sector
        sta header_sector
        eor header_id
        eor header_id + 1
        eor header_track
        sta header_parity
        jsr $f934               ; header to GCR

        lda #90                 ; retry counter for current track
        sta retry_sec_cnt
@retry:
        jsr drv_1541_wait_sync
        bcs @no_sync
@cmp_header:
        bvc @cmp_header         ; wait for byte ready
        lda $1c01               ; read data from head
        clv                     ; clear byte ready (V)
        cmp gcr_tmp, y          ; same header?
        bne @wrong_header
        iny
        cpy #8
        bne @cmp_header
        clc                     ; mark for success
@ret:
        rts

@wrong_header:
        dec retry_sec_cnt
        bpl @retry
        lda #ELOAD_SECTOR_NOT_FOUND
@no_sync:
        ; appearently we are on the wrong track or on no track at all
        dec retry_sh_cnt        ; retries left?
        bmi @ret                ; error code in A/C already
        jsr drv_1541_update_disk_info
        bcs @ret                ; if no readable header was found, bail out
                                ; error code in A/C already
        jsr drv_1541_move_head
        jmp @retry_new_track



.export write_sync
write_sync:
        lda #$ff
        sta $1c01               ; write $ff = sync
        ldy #5
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        dey
        bne :-
        rts

drive_code_1541_write_size  = * - drive_code_1541_write_start
.assert drive_code_1541_write_size <= 512, error, "drive_code_1541_write_size"
.reloc
