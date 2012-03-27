
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popa

    .import eload_send
    .import _eload_prepare_drive

gcr_overflow_size = 69


; =============================================================================
;
; void __fastcall__ eload_format(uint8_t n_tracks, uint16_t id);
;
; =============================================================================
.export _eload_format
_eload_format:
        sta id1
        stx id2

        jsr popa
        sta n_tracks

        php                     ; to backup the interrupt flag
        sei

        lda #2                  ; command: format
        sta job
        lda #<job
        ldx #>job
        ldy #4                  ; eload-jobs have always 4 bytes
        jsr eload_send

        plp                     ; to restore the interrupt flag
        rts

.bss

job:
        .res 1
n_tracks:
        .res 1
id1:
        .res 1
id2:
        .res 1
