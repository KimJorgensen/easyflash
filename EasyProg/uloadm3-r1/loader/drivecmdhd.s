

	.export drivecmdhd
	.import __DRIVECMDHD_LOAD__
	
drivecmdhd	= __DRIVECMDHD_LOAD__


	.segment "DRIVECMDHD"


	.include "drivecodejumptable.i"


serport	= $8000

retries	= 5			; number of retries when reading a sector
ledctl	= $4000			; LED control
ledbit	= $40
execjob	= $ff4e			; execute job
job3	= $23
trk3	= $2806
sct3	= $2807
zptmp	= $ff
track	= $f8
sector	= $f9
stack	= $fa

	.include "xfer_drive_2mhz_2bit.i"

drv_get_dir_ts:
	lda $2ba7
	sta track
	lda $2ba9
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

; set track (from x) and sector (from a) for read/write sector
drv_set_ts:
	stx track
	sta sector
	rts

; set the stack pointer (from x) to be restored upon exit
drv_set_exit_sp:
	stx stack
	rts
