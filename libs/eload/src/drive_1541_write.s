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
.import drv_1541_exec_this_job
.import drv_1541_recv_to_buffer
.import drv_1541_recv
.import drv_1541_send
.import drv_1541_wait_sync
.import drv_1541_move_head
.import drv_1541_bump
.import drv_1541_search_header
.import drv_1541_create_gcr_header

; number of used bytes on track 1 for all sectors incl.
; sync, header, header gap, sync, data block
track_1_net_bytes = 21 * (5 + 10 + 9 + 5 + 325)

.export drive_code_1541_write
drive_code_1541_write:

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

        dex
        bne @not_wr_sector
        jmp write_sector        ; eload job code: write 1

@not_wr_sector:
        dex
        bne @not_format
        jmp format_disk         ; eload job code: write 2

@not_format:
ret:
        rts

send_status_and_loop:
; send the return value from A and two bytes of status
        sta status
        lda #<status
        ldx #>status
        ldy #3
        jsr drv_1541_send
        jmp loop


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

        ; todo: gap too large?
        jsr write_sync

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
        lda #ELOAD_OK
motor_off_and_ret:
        pha
        jsr $f98f               ; prepare motor off (doesn't change C)
        pla
send_and_loop:
        jmp send_status_and_loop


; =============================================================================
;
;
; =============================================================================

timeout:
        lda #ELOAD_ERR_NO_SYNC
        jmp send_and_loop

format_disk:
        ; buffer content: | eload-job 2 | tracks | id1 | id2 |
        ldx buffer + 1
        inx
        stx end_track
        lda buffer + 2
        sta iddrv0
        lda buffer + 3
        sta iddrv0 + 1

        ; switch on motor, set bitrate for track 1, bump
        lda #1                  ; move this to bump function?
        sta current_track       ; we'll be on track 1
        jsr drv_1541_prepare_read
        jsr drv_1541_bump

        jsr write_gap_track     ; Write a track full of $55
        jsr write_sync          ; and sync
        jsr $fe00               ; head to read mode

        ; count bytes per track, should be about 7692 on track 1
        ldy #6                  ; start at overhead of this code
        ldx #0                  ; instead of 0
@count:
        nop                     ;  2   loop with 26 cycles = 1 byte
        jsr ret                 ; 12   to waste cylces
        iny                     ;  2   inc low byte of counter
        bne :+                  ;  3
        inx                     ;      inc high byte of counter
        beq timeout
:
        bit $1c00               ;  4   sync found?
        bmi @count              ;  3   no => wait and count
        clv                     ; clear byte ready (V)

        sty status + 1          ; YX = number of bytes on this track
        stx status + 2

        ; subtract the number of needed bytes from track length
        tya
        sec
        sbc #<track_1_net_bytes
        tay
        txa
        sbc #>track_1_net_bytes
        tax
        tya                     ; AX = all inter sector gap bytes on track 1

        ; divide the number of remaining bytes by number of sectors of track 1
        ldy #0
@divide:
        sec
        sbc sect_per_trk
        bcs :+
        dex
        bmi @divide_end
:
        iny                     ; Y = quotient = gap per sector for track 1..17
        jmp @divide
@divide_end:
        sty gcr_overflow_buff + 3   ; gap for speed zone 3
        iny
        sty gcr_overflow_buff       ; gap for speed zone 0
        tya
        clc
        adc #3
        sta gcr_overflow_buff + 1   ; gap for speed zone 1
        adc #5
        sta gcr_overflow_buff + 2   ; gap for speed zone 2

        lda #1
        sta job_track               ; start at track 1
format_next_track:
        jsr drv_1541_move_head
        ; === prepare up to 21 GCR encoded sectors in our buffer ===
        jsr drv_1541_prepare_read
        ldx speed_zone
        lda gcr_overflow_buff, x    ; read inter sector gap length
        sta format_gap_len

        lda #0                  ; start at sector 0
        sta job_sector
        sta @header_ptr
        lda #$07
@next_header:
        jsr drv_1541_create_gcr_header
        ldx #0                  ; read GCR index
@copy_header:
        lda gcr_tmp, x          ; copy GCR header
        ldy #0
@header_ptr = * + 1
        sta buffer              ; will be modified
        inc @header_ptr
        inx
        cpx #10
        bne @copy_header

        inc job_sector
        lda job_sector
        cmp sect_per_trk
        bne @next_header

        ; === write the track ===
        lda sect_per_trk        ; number of sectors
        sta job_sector          ; Not the actual sector number but sector count
        ldy #0
        sty zptmp               ; offset into header buffer
        jsr start_write_gap_256 ; write 256 * 0x55, will be the last gap later

write_next_sector:
		dey				        ; Y = #$ff
        sty $1c01               ; write $ff = sync
        ldy #5                  ; header sync (5 * $ff)
:
        wait_byte_ready
        dey
        bne :-

        ldx #10
        ldy zptmp               ; offset into header buffer
@write_header:
        lda buffer, y
        sta $1c01               ; write header
        wait_byte_ready
        iny
        dex
        bne @write_header
        sty zptmp               ; offset into header buffer

        lda #$55
        sta $1c01
        ldy #8                  ; 9 * 0x55 header gap
:
        wait_byte_ready
        dey
        bpl :-                  ; Y is #$ff after this loop

        sty $1c01
        ldy #5                  ; data block sync
:
        wait_byte_ready
        dey
        bne :-

        ldx #4                  ; index to GCR snippet
@next1:
        lda gcr_snippet_1, x    ; write part of block with checksum
        sta $1c01
        wait_byte_ready
        dex
        bpl @next1

        ldy #64                 ; 64 * 5 GCR bytes (64 * 4 = 256 bin)
@next2:
        ldx #4                  ; index to GCR snippet
@next3:
        lda gcr_snippet_2, x    ; rest of the block (contains 0 only)
        sta $1c01
        wait_byte_ready
        dex
        bpl @next3
        dey
        bne @next2

        dec job_sector
        beq skip_gap            ; don't write the last gap now to make sure
                                ; that sector 0 is not damaged
        lda #$55
        sta $1c01
format_gap_len = * + 1
        ldy #5                  ; n * 0x55 inter sector gap
:
        wait_byte_ready
        dey
        bne :-                  ; Y is #0 after this loop
        beq write_next_sector   ; always
skip_gap:
        jsr $fe00               ; head to read mode

        inc job_track
        lda job_track
end_track = * + 1
        cmp #36
        beq @end_format
        jmp format_next_track
@end_format:
        jsr $f98f               ; prepare motor off (doesn't change C)
        lda #ELOAD_OK
        jmp send_status_and_loop



write_sync:
        lda #$ff
        ldy #5
write_data:
        sta $1c01               ; write $ff = sync
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        dey
        bne :-
        rts

; =============================================================================
;
; Write 255 * $55 (gap)
; Do not use this in timing critical situation at the beginning if the gap
; as it switches on write mode first etc. there's a short delay at the
; beginning. However, it's fast at the end, just RTS. So you can continue with
; writing sync directly.
;
; returns:
;       Y = 0
;
; changes:
;       A
;
; =============================================================================
start_write_gap_256:
        jsr start_write
write_gap_256:
        lda #$55
        sta $1c01
        ldy #0
:
        wait_byte_ready
        dey
        bne :-                  ; Y = 0 after this loop
        rts

start_write:
        lda #$ff
        sta $1c03               ; data port output
        lda $1c0c
        and #$df                ; %111x => %110x
        sta $1c0c               ; write mode
        rts

; =============================================================================
;
; Write 256 * $55 (gap)
; Do not use this in timing critical situation at the beginning if the gap
; as it switches on write mode first etc. there's a short delay at the
; beginning. However, it's fast at the end, just RTS. So you can continue with
; writing sync directly.
;
; returns:
;       Y = 0
;       X = 255
;
; changes:
;       A
;
; =============================================================================
write_gap_track:
        jsr start_write
        ldx #31                             ; 32 * 256
:
        jsr write_gap_256
        dex
        bpl :-
        rts

gcr_snippet_1:
        .byte $4a, $29, $a5, $d4, $55       ; backwards, contains the checksum

gcr_snippet_2:
        .byte $4a, $29, $a5, $94, $52       ; backwards, contains zeros

drive_code_1541_write_size  = * - drive_code_1541_write_start
.assert drive_code_1541_write_size <= 512, error, "drive_code_1541_write_size"
.reloc
