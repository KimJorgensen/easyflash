

; =============================================================================
;
; Receive a byte from the drive over the fast protocol. Used internally only.
;
; parameters:
;       Byte in A
;
; return:
;       -
;
; changes:
;       A, Y, zptmp
;
; =============================================================================
        ; serport: | A_in | DEV | DEV | ACK_out || C_out | C_in | D_out | D_in |
drv_send:
        bit serport             ; check for ATN which means cancel
        bmi drv_exit

        sta zptmp
        lsr
        lsr
        lsr
        lsr
        tay                     ; get high nibble into Y

        ; Handshake Step 1: Drive signals byte ready with DATA low
        lda #$02
        sta serport

        ; I moved this after Step 1 because the C64
        ; makes SEI and the badline test now
        lda drv_sendtbl,y       ; get the CLK, DATA pairs for high nibble
        pha
        lda zptmp
        and #$0f                ; get low nibble into Y
        tay

        ; Handshake Step 2: Host sets CLK low to acknowledge
        lda #$04
@wait2:
        bit serport             ; wait for CLK low (that's 1!)
        beq @wait2
        ; between the last cycle of these two "bit serport" are 6..12 cycles

        ; Handshake Step 3: Host releases CLK - Timing base
        ; if CLK is high (that's 0!) already, skip 3 cycles
        bit serport
        beq @reduce_jitter
        nop                     ; 6 cycles vs. 3 cycles
        nop
@reduce_jitter:                 ; t = 3..6 (only 3 us jitter)

        ; 1 MHz code
        ; get the CLK, DATA pairs for high nybble
        lda drv_sendtbl,y       ;  7..
        sta serport             ; 11..14 - b0 b1 (CLK DATA)

        asl                     ; 13..
        and #$0f                ; 15..
        sta serport             ; 19..22 - b2 b3

        pla                     ; 23
        sta serport             ; 27..30 - b4 b5

        asl                     ; 29..
        and #$0f                ; 31..
        sta serport             ; 35..38 - b6 b7

        nop                     ; 37..
        nop                     ; 39..
        lda #$00                ; 41..
        sta serport             ; 47..50  set CLK and DATA high

        rts

drv_sendtbl:
        ; 0 0 0 0 b0 b2 b1 b3
        .byte $0f, $07, $0d, $05
        .byte $0b, $03, $09, $01
        .byte $0e, $06, $0c, $04
        .byte $0a, $02, $08, $00
drv_sendtbl_end:
        .assert (>drv_sendtbl) = (>drv_sendtbl_end), error, "drv_sendtbl crosses page boundary"


; =============================================================================
;
; =============================================================================
drv_exit:
        lda #0                        ; release IEC bus
        sta serport
        ldx stack
        txs
        cli
        rts

; =============================================================================
;
; =============================================================================
drv_recv:
        lda #$08                ; CLK low to signal that we're receiving
        sta serport

        lda serport                ; get EOR mask for data
        asl
        eor serport
        and #$e0
        sta @eor

        lda #$01
:        bit serport                ; wait for DATA low
        bmi drv_exit
        beq :-

        sei                        ; disable IRQs

        lda #0                        ; release CLK
        sta serport

        lda #$01
:        bit serport                ; wait for DATA high
        bne :-

        nop
        nop
        lda serport                ; get bits 7 and 5

        asl
        nop
        nop
        eor serport                ; get bits 6 and 4

        asl
        asl
        asl
        cmp ($00,x)
        eor serport                ; get 3 and 1

        asl
        nop
        nop
        eor serport                ; finally get 2 and 0

@eor = * + 1
        eor #$5e

        rts
