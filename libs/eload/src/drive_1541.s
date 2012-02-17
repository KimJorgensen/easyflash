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

.export drive_code_1541
drive_code_1541  = *

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; =============================================================================
.org $0300
.export drv_code_start
drv_code_start      = *
serport         = $1800

retries         = 2             ; number of retries when reading a sector

prev_file_track = $7e
prev_file_sect  = $026f

job_code        = $04
job_track       = $0e
job_sector      = $0f
zpptr           = job_track     ; two bytes used as pointer (when no job)

stack           = $8b

test1           = $10
test2           = $11

iddrv0          = $12           ; disk drive id
header_id       = $16           ; disk id
header_track    = $18
header_sector   = $19
header_parity   = $1a

current_track   = $22

gcr_tmp         = $24

buff_ptr        = $30

head_step_ctr   = $4a

zptmp               = $c1
job_code_backup     = $c2
job_track_backup    = $c3
job_sector_backup   = $c4
retry_sec_cnt       = $c5       ; retry counter for searching sectors
retry_udi_cnt       = $c6       ; retry counter for update_disk_info
retry_sh_cnt        = $c7       ; retry counter for search_header

eor_correction      = $103      ; not on zeropage (need abs addressing)

buffer              = $0700

.export drv_start
drv_start:
        tsx
        stx stack
        jsr drv_load_code
        jmp drv_main

.include "xfer_drive_1mhz.s"

; =============================================================================
;
; Release the IEC bus, restore SP and leave the loader code.
;
; =============================================================================
drv_exit:
        lda #0                        ; release IEC bus
        sta serport
        ldx stack
        txs
        cli
        rts

.export drive_code_init_size_1541: abs
drive_code_init_size_1541  = * - drv_code_start

.assert drive_code_init_size_1541 <= 256, error, "drive_code_init_size_1541"


; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
; The code above is uploaded to the drive with KERNAL mechanisms. It has to
; contain everything to transfer the rest of the code using the fast protocol.
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

; sector read subroutine. Returns clc if successful, sec if error
; job_track, job_sector are set
drv_readsector:
        ldy #$80                ; read sector job code
        jsr set_job_backup_ts

        ldy #retries            ; retry counter
@retry:
        jsr restore_orig_job
        jsr exec_current_job
        bcc @ret
        dey                     ; decrease retry counter
        bne @retry
@ret:
        rts                     ; C = error state, A = error code



; sector write subroutine. Returns clc if successful, sec if error
; job_track, job_sector are set
drv_writesector: ; 03d8
        jsr backup_ts

        jsr prepare_read
        jsr search_header
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
        ldy #5
@write_sync:
        stx $1c01               ; write $ff = sync
:
        bvc :-                  ; wait for byte ready
        clv                     ; clear byte ready (V)
        dey
        bne @write_sync
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
        rts


set_job_backup_ts:
        sty job_code_backup
backup_ts:
        lda job_track
        sta job_track_backup
        lda job_sector
        sta job_sector_backup
        rts

; Interrupts must be disabled when this is called, because we set the job code
; first.
restore_orig_job:
        lda job_code_backup
        sta job_code
restore_orig_job_ts:
        lda job_track_backup
        sta job_track
        lda job_sector_backup
        sta job_sector
        rts


exec_this_job:
        sty job_code
        stx job_track
        sta job_sector
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
        inc test2
        clv                     ; clear byte ready (V)
        rts
@timeout:
        sec                     ; mark for error
        lda #ELOAD_ERR_NO_SYNC
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
search_header:
        jsr move_head
        lda #2                  ; retry counter for track correction
        sta retry_sh_cnt
@retry_new_track:
        jsr prepare_read
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
        jmp restore_orig_job


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
prepare_read:
        lda $1c00
        and #$04                ; motor on?
        bne :+
        lda $3d
        sta $3e                 ; set flag for motor running
        jsr $f97e               ; switch motor on
        ldy #250                ; motor was off: wait for a while
        jsr wait_a_moment       ; wait when motor was off
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
        jsr wait_a_moment
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
        jsr wait_a_moment
        beq blink               ; always

blink_fast:
        lda $1c00
        eor #$08                ; LED invertieren
        and #$ff - 4            ; Motor aus
        sta $1c00
        ldy #50
        jsr wait_a_moment
        beq blink_fast          ; always
.endif

.include "drive_common.s"

        nop
        nop
        nop


.export drive_code_size_1541_all
drive_code_size_1541_all  = * - drv_code_start

.assert drive_code_size_1541_all <= $400, error, "drive_code_size_1541_all"
