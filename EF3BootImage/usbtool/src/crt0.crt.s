;
; Startup code for cc65 (C64 EasyFlash CRT)
; No IRQ support at the moment
;

        .export _exit
        .export __STARTUP__ : absolute = 1      ; Mark as startup

        .import _main

        .import initlib, donelib, copydata
        .import zerobss
        .import BSOUT
        .import __RAM_START__, __RAM_SIZE__     ; Linker generated

        .include "zeropage.inc"
        .include "c64.inc"

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

; ------------------------------------------------------------------------
; Actual code

.code

cold_start:
reset:
        ; same init stuff the kernel calls after reset
        ldx #0
        stx $d016
        jsr $ff84   ; Initialise I/O

        ; These may not be needed - depending on what you'll do
        jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

        ; Switch to second charset
        lda #14
        jsr BSOUT

        jsr zerobss
        jsr copydata

        ; and here
        ; Set argument stack ptr
        lda #<(__RAM_START__ + __RAM_SIZE__)
        sta sp
        lda #>(__RAM_START__ + __RAM_SIZE__)
        sta sp + 1

        jsr initlib
        jsr _main

_exit:
        jsr donelib
exit:
        jmp (reset_vector) ; reset, mhhh

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
        ; === starts the main application                            ===
        lda #EASYFLASH_16K + EASYFLASH_LED
        sta EASYFLASH_CONTROL
        jmp cold_start
trampoline_end:
.endproc

        .segment "VECTORS"
.word   0
reset_vector:
.word   ultimax_reset
.word   0 ;irq
