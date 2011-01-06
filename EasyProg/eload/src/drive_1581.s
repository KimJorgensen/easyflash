

.export drive_code_1581
drive_code_1581 = *

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; =============================================================================
.org $0300

serport         = $4001

retries         = 5             ; number of retries when reading a sector

prev_file_track = $4c
prev_file_sect  = $028b

job3            = $05
trk3            = $11
sct3            = $12
zptmp           = $45
track           = $5b
sector          = $5c
stack           = $5d

drivebuffer     = $0600

        jmp drv_start

.include "drivecode.s"
.include "xfer_drive_2mhz_2bit.s"

drv_send = drv_send_2mhz
drv_recv = drv_recv_2mhz

; sector read subroutine. Returns clc if successful, sec if error
drv_readsector:
        lda #$80                ; read sector job code
job:
        sta zptmp
        lda track
        sta trk3
        lda sector
        sta sct3

        ldy #retries		; retry counter
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

        dey                    ; decrease retry counter
        bne retry
failure:
        ;sec
        rts
success:
        clc
        rts

.reloc

.export drive_code_size_1581
drive_code_size_1581  = * - drive_code_1581
