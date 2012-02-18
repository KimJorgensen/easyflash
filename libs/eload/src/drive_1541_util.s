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


.export drive_code_1541_util
drive_code_1541_util  = *

; =============================================================================
;
; Drive code assembled to fixed address $0400 follows
;
; =============================================================================
.org $0400
.export drive_code_1541_util_start
drive_code_1541_util_start      = *

; =============================================================================
;
; Wait for sync from the drive. Return C clear if sync was found, C set
; when an error occured.
;
; parameters:
;       -
;
; return:
;       Y = 0       can be used by the caller as index
;       C           error indication
;       A           in case of an error: ELOAD_ERR_NO_SYNC
;
; changes:
;       A, flags
;
; =============================================================================
wait_sync:
        ldy #0
        lda #$d0
        sta $1805               ; init timeout
        clc                     ; mark for success
@wait:
        bit $1805               ; timeout?
        bpl @timeout
        bit $1c00               ; sync found?
        bmi @wait               ; no => wait
        lda $1c01               ; the byte
        clv                     ; clear byte ready (V)
        rts
@timeout:
        sec                     ; mark for error
        lda #ELOAD_ERR_NO_SYNC
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
.export drv_delay
drv_delay:
        ldx #0
:
        dex
        bne :-
        dey
        bne :-
        rts

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
        jsr move_head
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
        jsr wait_sync
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
        jsr update_disk_info
        bcs @ret                ; if no readable header was found, bail out
                                ; error code in A/C already
        jsr move_head
        jmp @retry_new_track


; =============================================================================
;
; =============================================================================
update_disk_info:
        lda #1
        sta retry_udi_cnt
@retry:
        ldy #$b0                ; seek sector job code
        ldx #1
        lda #0
        jsr exec_this_job
        bcc @ret

        dec retry_udi_cnt
        bmi @ret                ; no retry - no need to bump

        ldy #$c0                ; bump job code
        jsr exec_this_job
        bcc @retry              ; shouldn't fail
@ret:
        jmp drv_1541_restore_orig_job


; =============================================================================
;
;
; parameters:
;       -
;
; return:
;
; changes:
;
; =============================================================================
.export drv_1541_prepare_read
drv_1541_prepare_read:
        lda $1c00
        and #$04                ; motor on?
        bne :+
        lda $3d
        sta $3e                 ; set flag for motor running
        jsr $f97e               ; switch motor on
        ldy #250                ; motor was off: wait for a while
        jsr drv_delay           ; wait when motor was off
:
        lda $1c00
        ora #$08                ; switch LED on
        and #$9f                ; update bitrate
        ldy current_track
        cpy #31                 ; track >= 31: keep rate %00
        bcs @rate_ok
        cpy #25
        bcc @lt25
        ora #$20                ; track >= 25: bit rate %01
        bne @rate_ok
@lt25:
        ora #$40                ; track >= 18: bit rate %10
        cpy #18
        bcs @rate_ok
        ora #$60                ; otherwise: bit rate %11
@rate_ok:
        sta $1c00

        jsr $fe00               ; head to read mode
activate_soe:
        lda $1c0c
        ora #$0e
        sta $1c0c               ; activate SOE (byte ready)
        rts

move_head:
        sec
        lda job_track
        tax
        sbc current_track
        stx current_track
        asl
move_head_direct:
        sta head_step_ctr       ; < 0 == outwards, > 0 == inwards
@next_step:
        lda head_step_ctr
        beq @ret                ; 0 => no steps
        jsr $fa2e               ; head step
        ldy #7
        jsr drv_delay
        jmp @next_step
@ret:
        jsr activate_soe        ; deactivated by jsr $fa2e
        rts

.if 0
blink:
        lda $1c00
        eor #$08                ; LED invertieren
        and #$ff - 4            ; Motor aus
        sta $1c00
        ldy #250
        jsr drv_delay
        beq blink               ; always

blink_fast:
        lda $1c00
        eor #$08                ; LED invertieren
        and #$ff - 4            ; Motor aus
        sta $1c00
        ldy #50
        jsr drv_delay
        beq blink_fast          ; always
.endif

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
.export drv_1541_set_job_ts_backup
.export drv_1541_set_ts_backup
drv_1541_set_job_ts_backup:
        sty job_code_backup
drv_1541_set_ts_backup:
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
.export drv_1541_restore_orig_job
drv_1541_restore_orig_job:
        lda job_track_backup
        sta job_track
        lda job_sector_backup
        sta job_sector
        lda job_code_backup
        sta job_code
        rts

drive_code_1541_util_size  = * - drive_code_1541_util_start
.assert drive_code_1541_util_size <= 512, error, "drive_code_1541_util_size"
.reloc

