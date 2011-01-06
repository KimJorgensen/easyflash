

.export drive_code_1571
drive_code_1571  = *

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; =============================================================================
.org $0300

serport         = $1800

retries         = 5             ; number of retries when reading a sector

prev_file_track = $7e
prev_file_sect  = $026f

job3            = $03
trk3            = $0c
sct3            = $0d
zptmp           = $1b
track           = $8b
sector          = $8c
stack           = $8d

iddrv0          = $12           ; disk drive id
id              = $16           ; disk id

drivebuffer     = $0600

        jmp drv_start

.include "drivecode.s"
.include "xfer_drive_1mhz_2bit.s"
.include "xfer_drive_2mhz_2bit.s"

drv_send:
        jmp $f001
drv_recv:
        jmp $f001

; sector read subroutine. Returns clc if successful, sec if error
drv_readsector:
        lda #$80                ; read sector job code
job:
        sta zptmp
        lda track
        sta trk3
        lda sector
        sta sct3

        ldy #retries            ; retry counter
retry:
        lda zptmp
        sta job3

        cli
@wait:
        lda job3
        bmi @wait

        sei

        cmp #2                  ; check status
        bcc success

        lda id                  ; check for disk ID change
        sta iddrv0
        lda id + 1
        sta iddrv0 + 1

        dey                    ; decrease retry counter
        bne retry
failure:
        ;sec
        rts
success:
        clc
        rts

.reloc

.export drive_code_size_1571
drive_code_size_1571  = * - drive_code_1571
