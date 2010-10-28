drv_send:
	ldy #$02		; set DATA low to signal that we're sending
	sty serport

	sta zptmp
	lsr
	lsr
	lsr
	lsr
	tay
	lda drv_sendtbl,y	; get the CLK, DATA pairs for low nybble
	pha
	lda zptmp
	and #$0f
	tay

	lda #$04
:	bit serport		; wait for CLK low
	beq :-

	lda #0			; release DATA
	sta serport

	lda #$04
:	bit serport		; wait for CLK high
	bne :-

; 1 MHz code

	lda drv_sendtbl,y	; get the CLK, DATA pairs for high nybble
	sta serport

	asl
	and #$0f
	sta serport

	pla
	sta serport

	asl
	and #$0f
	sta serport

	nop 
	nop
	lda #$00		; set CLK and DATA high
	sta serport

	rts

drv_sendtbl:
	.byte $0f, $07, $0d, $05
	.byte $0b, $03, $09, $01
	.byte $0e, $06, $0c, $04
	.byte $0a, $02, $08, $00
drv_sendtbl_end:
	.assert (>drv_sendtbl) = (>drv_sendtbl_end), error, "drv_sendtbl crosses page boundary"


drv_exit:
	ldx stack
	txs
	rts

drv_recv:
	lda #$08		; CLK low to signal that we're receiving
	sta serport

;	lda serport		; get EOR mask for data
;	asl
;	eor serport
;	and #$e0
;	sta @eor

	lda #$01
:	bit serport		; wait for DATA low
	bmi drv_exit
	beq :-

	sei			; disable IRQs

	lda #0			; release CLK
	sta serport

	lda #$01
:	bit serport		; wait for DATA high
	bne :-

	nop
	nop
	lda serport		; get bits 7 and 5

	asl
	nop
	nop
	eor serport		; get bits 6 and 4

	asl
	asl
	asl
	cmp ($00,x)
	eor serport		; get 3 and 1

	asl
	nop
	nop
	eor serport		; finally get 2 and 0

;@eor = * + 1
;	eor #$5e

	rts
