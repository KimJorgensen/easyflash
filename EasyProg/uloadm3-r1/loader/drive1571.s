

	.export drive1571
	.import __DRIVE1571_LOAD__
	
drive1571	= __DRIVE1571_LOAD__


	.import drivebuffer
	.import track_list, sector_list


	.segment "DRIVE1571"


	.include "drivecodejumptable.i"


serport		= $1800

retries		= 5		; number of retries when reading a sector
ledctl		= $1c00		; LED control
ledbit		= $08
job3		= $03
trk3		= $0c
sct3		= $0d
zptmp		= $1b

iddrv0		= $12		; disk drive id
id		= $16		; disk id

secpertrk	= $f24b		; get number of sectors in track
jobok		= $f505
waitsync        = $f556         ; wait for sync
decode          = $f7e8         ; decode 5 GCR bytes, bufferindex in Y
bufptr		= $30


drv_get_dir_ts:
	lda #18
	sta track
	lda #1
	sta sector
	clc
	; fall through

; flush, perform after writing sectors
drv_flush:
	rts


; sector read subroutine. Returns clc if successful, sec if error
drv_readsector:
	lda #$80		; read sector job code
	jmp job


; sector write subroutine. Returns clc if successful, sec if error
drv_writesector:
	lda #$90
	;jmp job

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


	.include "xfer_drive_2mhz_2bit.i"
