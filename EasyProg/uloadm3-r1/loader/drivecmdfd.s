

	.export drivecmdfd
	.import __DRIVECMDFD_LOAD__
	
drivecmdfd	= __DRIVECMDFD_LOAD__


	.segment "DRIVECMDFD"


	.include "drivecodejumptable.i"


serport		= $4001

retries	= 5			; number of retries when reading a sector
ledctl	= $4000			; LED control
ledbit	= $40
execjob	= $ff54			; execute job
job3	= $05
trk3	= $11
sct3	= $12
zptmp	= $13


drv_get_dir_ts:
	lda $54
	sta track
	lda $56
	sta sector
	clc
	rts


; sector read subroutine. Returns clc if successful, sec if error
drv_readsector:
	lda #$80		; read sector job code
	jmp job


; sector write subroutine. Returns clc if successful, sec if error
drv_writesector:
	lda #$90
	jmp job


; flush, perform after writing sectors
drv_flush:
	lda #$a2
	;jmp job


job:
	sta zptmp
	sta job3
	lda track
	sta trk3
	lda sector
	sta sct3

	ldy #retries		; retry counter
	jsr blink		; turn on led

retry:
	ldx #3			; job 3
	lda zptmp
	jsr execjob
	lda job3		; cmd fd doesn't return status

	cmp #2			; check status
	bcc success

	dey			; decrease retry counter
	bne retry
drv_track_ts:
failure:
	sec
	rts
success:
	clc
blink:
	lda ledctl		; blink LED
	eor #ledbit
	sta ledctl
	rts


	.include "xfer_drive_2mhz_2bit.i"
