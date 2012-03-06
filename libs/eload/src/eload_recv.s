
.importzp ptr1

.include "config.s"

; =============================================================================
;
; parameters:
;       AX  pointer to data
;       Y   number of bytes (1 for 256=0)
;
; return:
;       A contains last byte received (lowest address)
;       Y = 0
;
; changes:
;       flags
;
; =============================================================================
.export eload_recv
eload_recv:
        sta ptr1
        stx ptr1 + 1

        ; $dd00: | D_in | C_in | D_out | C_out || A_out | RS232 | VIC | VIC |
        ; Handshake Step 1: Drive signals data ready with DATA low
        ; only wait when 1st byte is transferred
:
        lda $dd00
        bmi :-
@next_byte:
@eload_recv_waitbadline:
        lda $d011               ; wait until a badline won't screw up
        clc                     ; the timing
        sbc $d012
        and #7
        beq @eload_recv_waitbadline

        ; Handshake Step 2: Host sets CLK low when ready
        lda $dd00
        ora #$10
        sta $dd00

        and #$03                ; 2
        sta @eor+1              ; 6     correction for video bank bits

        ; Release CLK so we can read it later
        sta $dd00               ; 10    CLK was low for ~10 us


        ; Handshake Step 3: Drive releases DATA to start
:                               ; CLK       PAL us  NTSC us
        lda $dd00               ;                           wait for DATA high
        bpl :-                  ; 3..9

        bit $ff                 ; 6..

        ; receive bits
        lda $dd00               ; 10..16    10..16  10..16  b3 b1
        lsr
        lsr                     ; 14..
        eor $dd00               ; 18..24    18..24  18..23  b2 b0
        lsr
        lsr                     ; 22..
        nop
        nop
        bit $ff                 ; 29..
        eor $dd00               ; 33..39    34..40  32..38  b7 b5
        lsr
        lsr                     ; 37..
@eor:
        eor #$00                ; 39..
        eor $dd00               ; 43..49    44..50  42..48  b6 b4

        dey
        sta (ptr1), y
        bne @next_byte
        rts
