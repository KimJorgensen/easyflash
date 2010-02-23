;
; Startup code for cc65 (C64 EasyFlash CRT)
;

        .export         _exit
        .export         __STARTUP__ : absolute = 1      ; Mark as startup

        .import	        _main

;        .import         initlib, donelib, copydata
;        .import         zerobss
;	.import	   __INTERRUPTOR_COUNT__
;	.import		__RAM_START__, __RAM_SIZE__	; Linker generated

;	.include "zeropage.inc"
;	.include "c64.inc"

;	.export	_sv_irq_timer_counter, _sv_irq_dma_counter
;	.export	_sv_nmi_counter

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

.bss

;_sv_irq_dma_counter:    .byte 0
;_sv_irq_timer_counter:  .byte 0
;_sv_nmi_counter:        .byte 0

; ------------------------------------------------------------------------
; Place the startup code in a special segment.

.segment           "STARTUP"

; cold start vector
        .word cold_start

; warm start vector
        .word cold_start

; magic string
        .byte $c3, $c2, $cd, $38, $30

; ------------------------------------------------------------------------
; Actual code

.code

cold_start:
reset:
        ; same init stuff the kernel calls after reset normally
        ldx #0
        stx $d016
        jsr $ff84   ; Initialise I/O

        ; These may not be needed - depending on what you'll do
        jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

;	jsr	zerobss

	; initialize data
;	jsr	copydata

;	lda	#>(__RAM_START__ + __RAM_SIZE__)
;	sta	sp+1   		; Set argument stack ptr
;	stz	sp              ; #<(__RAM_START__ + __RAM_SIZE__)
;	jsr	initlib
        jsr     _main

_exit:
;        jsr     donelib
exit:
        jmp     exit


;.proc   irq
;	pha
;	lda	sv_irq_source
;	and	#SV_IRQ_REQUEST_TIMER
;	beq	not_timer
;	lda	sv_timer_quit
;	inc	_sv_irq_timer_counter
;not_timer:
;	lda	sv_irq_source
;	and	#SV_IRQ_REQUEST_DMA
;	beq	not_dma
;	lda	sv_dma_quit
;	inc	_sv_irq_dma_counter
;not_dma:
;	pla
;	rti
;.endproc

;.proc   nmi
;	inc	_sv_nmi_counter
;	rti
;.endproc

; ------------------------------------------------------------------------
; This code is executed in Ultimax mode. It is called directly from the
; reset vector and must do some basic hardware initializations.
; It also contains trampoline code which will switch to 16k cartridge mode
; and call the normal startup code.
;
        .segment "ULTIMAX"
.proc ultimax_reset
ultimax_reset:
        ; === the reset vector points here ===
        sei
        ldx #$ff
        txs
        cld

        ; enable VIC (e.g. RAM refresh)
        lda #8
        sta $d016

        ; write to RAM to make sure it starts up correctly (=> RAM datasheets)
wait:
        sta $0100, x
        dex
        bne wait

        ; copy the final start-up code to RAM (bottom of CPU stack)
        ldx #(trampoline_end - trampoline)
l1:
        lda trampoline, x
        sta $0100, x
        dex
        bpl l1
        jmp $0100

trampoline:
        ; === this code is copied to the stack area, does some inits ===
        ; === scans the keyboard and kills the cartridge or          ===
        ; === starts the main application                            ===
        lda #EASYFLASH_16K + EASYFLASH_LED
        sta EASYFLASH_CONTROL

        ; Check if one of the magic kill keys is pressed
        ; This should be done in the same way on any EasyFlash cartridge!

        ; Prepare the CIA to scan the keyboard
        lda #$7f
        sta $dc00   ; pull down row 7 (DPA)

        ldx #$ff
        stx $dc02   ; DDRA $ff = output (X is still $ff from copy loop)
        inx
        stx $dc03   ; DDRB $00 = input

        ; Read the keys pressed on this row
        lda $dc01   ; read coloumns (DPB)

        ; Restore CIA registers to the state after (hard) reset
        stx $dc02   ; DDRA input again
        stx $dc00   ; Now row pulled down

        ; Check if one of the magic kill keys was pressed
        and #$e0    ; only leave "Run/Stop", "Q" and "C="
        cmp #$e0
        bne kill    ; branch if one of these keys is pressed

        ; same init stuff the kernel calls after reset
        ldx #0
        stx $d016
        jsr $ff84   ; Initialise I/O

        ; These may not be needed - depending on what you'll do
        jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

        ; Branch to the normal start-up code
        jmp cold_start

kill:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        jmp ($fffc) ; reset
trampoline_end:
.endproc

        .segment "VECTORS"
.word   0 ;nmi
.word   ultimax_reset
.word   0 ;irq
