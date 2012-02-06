
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popax

    .import eload_send_nodma
    .import eload_send
    .import eload_recv
    .import _eload_prepare_drive

gcr_overflow_size = 69


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
        sta job
        lda #<job
        ldx #>job
        ldy #1
        jsr eload_send

        lda #<trk_tmp
        ldx #>trk_tmp
        ldy #2
        jsr eload_send

        ; this will go to the GCR overflow buffer $1bb
        lda block_tmp
        ldx block_tmp + 1
        ldy #gcr_overflow_size
        jsr eload_send_nodma

        lda block_tmp + 1
        adc #0
        sta block_tmp + 1

        ; this will go to the main buffer
        clc
        lda block_tmp
        adc #gcr_overflow_size
        tay
        lda block_tmp + 1
        adc #0
        tax
        tya
        ldy #0
        jsr eload_send_nodma

        jsr eload_recv
        ldx #0
        rts

.bss
; keep the order of these three bytes
job:
        .res 1
trk_tmp:
        .res 1
sec_tmp:
        .res 1
block_tmp:
        .res 2
