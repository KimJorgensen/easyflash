
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popax

    .import eload_send256_nodma
    .import eload_send
    .import eload_recv
    .import _eload_prepare_drive

; =============================================================================
;
; uint8_t __fastcall__ eload_write_sector(unsigned ts, uint8_t* block);
;
; =============================================================================
.export _eload_write_sector_nodma
_eload_write_sector_nodma:
        sta block_tmp
        stx block_tmp + 1       ; Save buffer

        jsr popax
        stx trk_tmp             ; track
        sta sec_tmp             ; sector

        lda #4                  ; command: write sector
        jsr eload_send
        lda trk_tmp
        jsr eload_send
        lda sec_tmp
        jsr eload_send

        lda block_tmp
        ldx block_tmp + 1
        jsr eload_send256_nodma

        jsr eload_recv
        ldx #0
        rts

.bss
trk_tmp:
        .res 1
sec_tmp:
        .res 1
block_tmp:
        .res 2
