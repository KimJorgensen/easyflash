
        .export __STARTUP__ : absolute = 1      ; Mark as startup
        .import __RAM_START__, __RAM_SIZE__     ; Linker generated

        .include "zeropage.inc"
        .include "c64.inc"

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

; =============================================================================
; JMP table
; =============================================================================
.segment "JMP_CODE"
        jmp dec_d021

; =============================================================================
; =============================================================================
.code


; =============================================================================
dec_d021:
        dec $d021
        rts

; =============================================================================
;
; This reset function is not executed usually, it's here just for tests with
; vice.
;
; =============================================================================
test_reset:
        ; === the reset vector points here ===
        sei
        ldx #$ff
        txs
        cld

        ; enable VIC (e.g. RAM refresh)
        lda #8
        sta $d016

        ; write to RAM to make sure it starts up correctly (=> RAM datasheets)
@wait:
        sta $0100, x
        dex
        bne @wait
:
        inc $d020
        jmp :-

; =============================================================================
;
; =============================================================================
irq_ret:
        rti

; =============================================================================
; Common code on all KERNAL banks
; =============================================================================
.segment "KERNAL_COMMON"
.include "kernal_common.s"

; these vectors are not used usually as this is the KERNAL bank 1
.segment "VECTORS"
.word   irq_ret
.word   test_reset
.word   irq_ret
