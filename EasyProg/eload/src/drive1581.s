

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
track	= $5b
sector	= $5c
stack	= $5d

bufptr	= $5e

	.include "xfer_drive_2mhz_2bit.i"

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
	bne job


; sector write subroutine. Returns clc if successful, sec if error
drv_writesector:
	lda #$90
	bne job


; flush, perform after writing sectors
drv_flush:
	lda #$a2

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
	lda zptmp
	sta job3

	cli
@wait:
	lda job3
	bmi @wait

	sei

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

; set track (from x) and sector (from a) for read/write sector
drv_set_ts:
	stx track
	sta sector
	rts

; set the stack pointer (from x) to be restored upon exit
drv_set_exit_sp:
	stx stack
	rts
