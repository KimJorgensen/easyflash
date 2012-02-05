
.importzp   tmp3
.import     sendtab

.export     eload_send

; =============================================================================
;
; Send a byte to the drive over the fast protocol. Used internally only.
; This version does not use SEI/CLI, the caller must care for it.
;
; parameters:
;       Byte in A
;
; return:
;       -
;
; changes:
;   A, Y,
;
; =============================================================================
eload_send:
        pha
        lsr
        lsr
        lsr
        lsr
        tay

        lda $dd00
        sta tmp3
        and #7
        sta $dd00
        eor #$07
        ora #$38
        sta $dd02

@waitdrv:
        bit $dd00       ; wait for drive to signal ready to receive
        bvs @waitdrv    ; with CLK low

        lda #$20        ; pull DATA low to acknowledge
        sta $dd00

@wait2:
        bit $dd00       ; wait for drive to release CLK
        bvc @wait2

eload_send_waitbadline:
        lda $d011       ; wait until a badline won't screw up
        clc             ; the timing
        sbc $d012
        and #7
        beq eload_send_waitbadline
eload_send_nobadline:
        nop             ; <= NOP makes sure the code below is after the bad line

        lda #$00        ; release DATA to signal that data is coming
        sta $dd00

        lda sendtab,y   ; 4
        sta $dd00       ; 8     send bits 7 and 5

        lsr             ; 10
        lsr             ; 12
        and #%00110000  ; 14
        sta $dd00       ; 18    send bits 6 and 4

        pla             ; 22    get the next nibble
        and #$0f        ; 24
        tay             ; 26
        lda sendtab,y   ; 30
        sta $dd00       ; 34    send bits 3 and 1

        lsr             ; 36
        lsr             ; 38
        and #%00110000  ; 40
        sta $dd00       ; 44    send bits 2 and 0

        nop             ; 46
        nop             ; 48
        lda tmp3        ; 51
        ldy #$3f        ; 53
        sta $dd00       ; 57    restore $dd00 and $dd02
        sty $dd02
        rts
