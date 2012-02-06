
.importzp   tmp3, ptr3
.import     sendtab

.export     eload_send

; =============================================================================
;
; Send up to 256 bytes to the drive over the fast protocol. The last byte is
; sent first.
;
; This version does not use SEI/CLI, the caller must care for it.
;
; Used internally only.
;
; parameters:
;       AX  pointer to data
;       Y   number of bytes (1 for 256=0)
;
; return:
;       -
;
; changes:
;   A, X, Y
;
; =============================================================================
eload_send:
        sta ptr3
        stx ptr3 + 1

        lda $dd00
        sta tmp3
        and #7
        sta $dd00
        eor #$07
        ora #$38
        sta $dd02

@next_byte:
        dey
        lda (ptr3), y

@waitdrv:
        bit $dd00       ; wait for drive to signal ready to receive
        bvs @waitdrv    ; with CLK low

        ldx #$20        ; pull DATA low to acknowledge
        stx $dd00

        pha
        lsr
        lsr
        lsr
        lsr
        tax

@wait2:
        bit $dd00       ; wait for drive to release CLK
        bvc @wait2

@waitbadline:
        lda $d011       ; wait until a badline won't screw up
        clc             ; the timing
        sbc $d012
        and #7
        beq @waitbadline
@nobadline:
        nop             ; <= NOP makes sure the code below is after the bad line

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
        ldx #$3f        ; 48
        lda tmp3        ; 51
        cpy #0          ; 53
        sta $dd00       ; 57    restore $dd00 and $dd02

        bne @next_byte  ;       Z from cpy

        stx $dd02
        rts
