

.export drive_code_1541
drive_code_1541  = *

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; =============================================================================
.org $0300

serport         = $1800

retries         = 5             ; number of retries when reading a sector
ledctl          = $1c00         ; LED control
ledbit          = $08

header_track    = $18
header_sector   = $19

job3            = $03
trk3            = $0c
sct3            = $0d
zptmp           = $1b
track           = $8b
sector          = $8c
stack           = $8d

iddrv0          = $12           ; disk drive id
id              = $16           ; disk id

secpertrk       = $f24b         ; get number of sectors in track
jobok           = $f505
waitsync        = $f556         ; wait for sync
decode          = $f7e8         ; decode 5 GCR bytes, bufferindex in Y
bufptr          = $30

drivebuffer     = $0600
track_list      = drivebuffer + $80
sector_list     = drivebuffer + $c0

        jmp drv_start

        .include "xfer_drive_1mhz_2bit.i"
        .include "drivecode.s"


; sector read subroutine. Returns clc if successful, sec if error
drv_readsector:
	lda #$80		; read sector job code
job:
	sta zptmp
	lda track
	sta trk3
	lda sector
	sta sct3

	ldy #retries		; retry counter
	jsr blink		; turn on led

retry:
	lda zptmp
	sta job3

	cli
@wait:
	lda job3
	bmi @wait

	sei

	cmp #2			; check status
	bcc success

	lda id			; check for disk ID change
	sta iddrv0
	lda id + 1
	sta iddrv0 + 1

	dey			; decrease retry counter
	bne retry
failure:
	;sec
	rts
success:
	clc
blink:
	lda ledctl		; blink LED
	eor #ledbit
	sta ledctl
	rts

.reloc

.export drive_code_size_1541
drive_code_size_1541  = * - drive_code_1541
