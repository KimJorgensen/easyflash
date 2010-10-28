

	.export drive1581
	.import __DRIVE1581_LOAD__
	
drive1581	= __DRIVE1581_LOAD__


	.import drivebuffer
	.import track_list, sector_list


	.segment "DRIVE1581"


	.include "drivecodejumptable.i"


serport		= $4001

retries	= 5			; number of retries when reading a sector
ledctl	= $4000			; LED control
ledbit	= $40
execjob	= $ff54			; execute job
job3	= $05
trk3	= $11
sct3	= $12
zptmp	= $45

bufptr	= $5e


drv_get_dir_ts:
	lda $022b
	sta track
	lda #3
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
	lda track
	sta trk3
	lda sector
	sta sct3

	ldy #retries		; retry counter
	lda ledctl		; turn on led
	ora #ledbit
	sta ledctl

retry:
	ldx #3			; job 3
	lda zptmp
	jsr execjob

	cmp #2			; check status
	bcc success

	dey			; decrease retry counter
	bne retry
failure:
	;sec
	rts
success:
	clc

	lda ledctl		; blink LED
	and #~ledbit
	sta ledctl
	rts


	.include "xfer_drive_2mhz_2bit.i"
