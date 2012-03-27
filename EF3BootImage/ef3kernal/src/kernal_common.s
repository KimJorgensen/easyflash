
; =============================================================================
; Common code on all KERNAL banks
;
; This code goes to $fec2 and is used on Bank 0 (acme) and all other banks
; (ca65). That's why the syntax has to use the common subset of both
; assemblers.
;
; =============================================================================

; I/O address to set the KERNAL bank
EASYFLASH3_IO_KERNAL_BANK   = $de0e

ram_jsr_op  = $dff0
ram_jsr_lo  = $dff1
ram_jsr_hi  = $dff2

; =============================================================================
; JSR to a subroutine on bank 0 and return to bank 1. The address to be JSRed
; to is at ram_jsr_lo/ram_jsr_hi. All registers are forwarded transparently.
; =============================================================================
bank1_jsr_to_bank0:
        pha
        lda #$4c                ; opcode of JMP
        sta ram_jsr_op
        lda #0
        sta EASYFLASH3_IO_KERNAL_BANK
        pla
        jsr $dff0
        pha
        lda #1
        sta EASYFLASH3_IO_KERNAL_BANK
        pla
        rts

; =============================================================================
; Same as bank1_jsr_to_bank0, but different banks
; =============================================================================
bank0_jsr_to_bank1_ax:
        sta ram_jsr_lo
        stx ram_jsr_hi
bank0_jsr_to_bank1:
        pha
        lda #$4c                ; opcode of JMP
        sta ram_jsr_op
        lda #1
        sta EASYFLASH3_IO_KERNAL_BANK
        pla
        jsr $dff0
        pha
        lda #0
        sta EASYFLASH3_IO_KERNAL_BANK
        pla
        rts
