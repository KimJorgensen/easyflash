
.importzp   tmp3, ptr3
.import     sendtab

.export     eload_send256_nodma

; =============================================================================
;
; Send 256 bytes to the drive over the fast protocol. Do not wait for any
; VIC-II DMA.
;
; Used internally only.
;
; Uses SEI/CLI.
;
; parameters:
;       Pointer in AX
;
; return:
;       -
;
; changes:
;   A, Y,
;
; =============================================================================
eload_send256_nodma:
        sta ptr3
        stx ptr3 + 1

        lda $dd00
        and #7
        sta $dd00
        sta tmp3        ; <= mhhh?
        eor #$07
        ora #$38
        sta $dd02

        sei

        ldy #0
@next_byte:
        lda (ptr3), y

        pha
        lsr
        lsr
        lsr
        lsr
        tax

@waitdrv:
        bit $dd00       ; wait for drive to signal ready to receive
        bvs @waitdrv    ; with CLK low

        lda #$20        ; pull DATA low to acknowledge
        sta $dd00

@wait2:
        bit $dd00       ; wait for drive to release CLK
        bvc @wait2

        lda #$00        ; release DATA to signal that data is coming
        sta $dd00

        lda sendtab,x   ; 4
        sta $dd00       ; 8     send bits 7 and 5

        lsr             ; 10
        lsr             ; 12
        and #%00110000  ; 14
        sta $dd00       ; 18    send bits 6 and 4

        pla             ; 22    get the next nibble
        and #$0f        ; 24
        tax             ; 26
        lda sendtab,x   ; 30
        sta $dd00       ; 34    send bits 3 and 1

        lsr             ; 36
        lsr             ; 38
        and #%00110000  ; 40
        sta $dd00       ; 44    send bits 2 and 0

        nop             ; 46
        ldx #$3f        ; 48    (for $dd02 below)
        lda tmp3        ; 51
        iny             ; 53
        sta $dd00       ; 57    restore $dd00

        bne @next_byte  ;       Z from iny

        stx $dd02

        cli
        rts
