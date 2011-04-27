
.include "c64.inc"

.importzp tmp1, tmp2, tmp3

RPTFLG          = $028a
CHROUT_SCREEN   = $e716


; =============================================================================
.bss

; =============================================================================
.rodata
hexDigits:
        .byte "0123456789ABCDEF"

; =============================================================================
.code

; =============================================================================
; Configure key repeat.
; uint8_t __fastcall__ screenSetKeyRepeat(uint8_t val)
;
; parameters:
;       KEY_REPEAT_* in A (X ignored)
; return:
;       previous setting in AX (A = low, X can be ignored)
;
; =============================================================================
.export _screenSetKeyRepeat
_screenSetKeyRepeat:
        ldx RPTFLG
        sta RPTFLG
        txa
        ldx #0
        rts

; =============================================================================
; Make a small delay proportional to t.
; void __fastcall__ screenDelay(unsigned t)
;
; parameters:
;       t in AX (A = low)
; return:
;       -
;
; =============================================================================
.export _screenDelay
_screenDelay:
        tay
@wait:
        dey
        bne @wait
        dex
        bne @wait
        rts

; =============================================================================
; void __fastcall__ screenPrintHex2(uint8_t n)
;
; parameters:
;       n in A
; return:
;       -
;
; =============================================================================
.export _screenPrintHex2
_screenPrintHex2:
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda hexDigits, x
        jsr CHROUT_SCREEN
        pla
        and #$0f
        tax
        lda hexDigits, x
        jmp CHROUT_SCREEN

; =============================================================================
; void __fastcall__ screenPrintHex4(uint16_t n)
;
; parameters:
;       n in AX
; return:
;       -
;
; =============================================================================
.export _screenPrintHex4
_screenPrintHex4:
        pha
        txa
        jsr _screenPrintHex2
        pla
        jmp _screenPrintHex2
