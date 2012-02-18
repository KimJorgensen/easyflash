 ;
 ; ELoad
 ;
 ; (c) 2011 Thomas Giesel
 ; transfer code based on work by Per Olofsson
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

gcr_overflow_size = 69
gcr_overflow_buff = $01bb

; =============================================================================
;
; load file
; args: start track, start sector
; returns: $00 for EOF, $ff for error, $01-$fe for each data block
;
; =============================================================================
load:
        ldx prev_file_track
        lda prev_file_sect
loadchain:
@sendsector:
        jsr drv_readsector
        bcc :+
        lda #$ff                ; send read error
        jmp error
:
        ldx #254                ; send 254 bytes (full sector)
        lda buffer              ; last sector?
        bne :+
        ldx buffer + 1          ; send number of bytes in sector (1-254)
        dex
:
        stx @buflen
        txa
        jsr drv_send           ; send byte count

        ldx #0                  ; send data
@send:
        txa
        pha
        lda buffer + 2,x
        jsr drv_send
        pla
        tax
        inx
@buflen = * + 1
        cpx #$ff
        bne @send

        ; load next t/s in chain into x/a or exit loop if EOF
        ldx buffer
        beq @done
        lda buffer + 1
        jmp @sendsector
@done:
        lda #0
        jmp senddone

; =============================================================================
;
; =============================================================================
drv_main:
        cli                     ; allow IRQs when waiting
        jsr drv_wait_rx         ; does SEI when data is signaled

        ldy #1
        jsr drv_recv_to_buffer  ; get command byte

        cmp #1                  ; load a file
        beq load

        cmp #4
        beq write_sector

        lda #ELOAD_UNKNOWN_CMD  ; unknown command
senddone:
error:
        jsr drv_send
        jmp drv_main

; =============================================================================
;
; Used in all versions of the send function
;
; =============================================================================
drv_sendtbl:
        ; 0 0 0 0 b0 b2 b1 b3
        .byte $0f, $07, $0d, $05
        .byte $0b, $03, $09, $01
        .byte $0e, $06, $0c, $04
        .byte $0a, $02, $08, $00

; =============================================================================
write_sector: ; 05db
        ldy #2
        lda #<job_track         ; receive track and secor
        ldx #>job_track
        jsr drv_recv

        ; receive 69 + 256 bytes of GCR encodec track
        ldy #gcr_overflow_size
        lda #<gcr_overflow_buff
        ldx #>gcr_overflow_buff
        jsr drv_recv            ; 69 bytes
        jsr drv_recv_to_buffer  ; 256 bytes (Y = 0 from prev call)

        ldx job_track
        lda job_sector
        jsr drv_writesector
        bcs @ret
        lda #ELOAD_OK
@ret:
        jmp senddone        ; send OK or error

; =============================================================================
;
; Execute the job in Y (job code), X (track) and A (sector)
;
; Return C set and error code in A in case of an error.
;
; =============================================================================

exec_this_job:
        sty job_code
        stx job_track
        sta job_sector
        ; fall through

; =============================================================================
;
; Execute the job in job_code/job_track/job_sector
;
; Return C set and error code in A in case of an error.
;
; =============================================================================
exec_current_job:
        cli
@wait:
        lda job_code            ; let the job run in IRQ
        bmi @wait
        sei

        ldx header_id           ; check for disk ID change
        stx iddrv0
        ldx header_id + 1
        stx iddrv0 + 1

        cmp #2                  ; check status
        rts                     ; C = error state, A = error code

; =============================================================================
;
; Set Y/X/A to backup of job code, track and sector
;
; =============================================================================
set_job_ts_backup:
        sty job_code_backup
set_ts_backup:
        stx job_track_backup
        sta job_sector_backup
        rts

; =============================================================================
;
; Copy job code, track and sector from backup to current job.
;
; changes: A
;
; =============================================================================
restore_orig_job:
        lda job_track_backup
        sta job_track
        lda job_sector_backup
        sta job_sector
        lda job_code_backup
        sta job_code
        rts

; =============================================================================
;
; Wait about Y * 1.3 ms
;
; parameters:
;       Y time factor
;
; return:
;       Z flag set
;
; =============================================================================
wait_a_moment:
        ldx #0
:
        dex
        bne :-
        dey
        bne :-
        rts
