
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popax

    .import eload_send
    .import eload_recv
    .import _eload_prepare_drive

gcr_overflow_size = 69


; =============================================================================
;
; void __fastcall__ _eload_format(void);
;
; =============================================================================
.export _eload_format
_eload_format:
        php                     ; to backup the interrupt flag
        sei

        lda #2                  ; command: format
        sta job
        lda #<job
        ldx #>job
        ldy #3                  ; always send 3 bytes (2 are not used here)
        jsr eload_send

        plp                     ; to restore the interrupt flag
        rts

.bss

job:
        .res 1
