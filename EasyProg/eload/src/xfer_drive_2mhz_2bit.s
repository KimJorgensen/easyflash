

; =============================================================================
;
; Send a byte to the host.
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
        bit serport             ; check for ATN
        bmi drv_exit            ; leave the drive code if it is active

        ; Handshake Step 1: Drive signals byte ready with DATA low
        ldy #$02
        sty serport

        ; I moved this after Step 1 because the C64
        ; makes SEI and the badline test now
        tay
        lsr
        lsr                     ; prepare high nibble
        lsr                     ; 4th shift after pla
        pha

        ; Handshake Step 2: Host sets CLK low to acknowledge
        lda #$04
@wait2:
        bit serport             ; wait for CLK low (that's 1!)
        beq @wait2

        ; Handshake Step 3: Host releases CLK - Timing base
@wait2:
        bit serport             ; wait for CLK high (that's 0!)
        bne @wait2              ; t = 3..9 * 0.5 us = 1.5..4.5 us

        ; 2 MHz code
        ; get CLK, DATA pairs for low nibble
        tya                     ;  5..
        and #$0f                ;  7..
        tay                     ;  9..
        lda drv_sendtbl,y       ; 13..
        pha                     ; 16..
        pla                     ; 20..

        sta serport             ; 24..30 - b0 b1 (CLK DATA)

        asl                     ; 26..
        and #$0f                ; 28..
        nop
        nop
        nop
        nop                     ; 36..
        sta serport             ; 40..46 - b2 b3

        pla                     ; 44..
        lsr                     ; 46.. 4th shift
        tay                     ; 48..
        lda drv_sendtbl,y       ; 52..  get CLK, DATA pairs for high nibble
        sta serport             ; 56..62 - b4 b5

        asl                     ; 58..
        and #$0f                ; 60..
        nop
        nop
        nop
        nop                     ; 68..
        sta serport             ; 72..78 - b6 b7

        jsr @delay12            ; 84
        nop
        nop
        nop                     ; 90..
        lda #$00                ; 92..
        sta serport             ; 96..102  set CLK and DATA high
@delay12:
        rts

drv_sendtbl:
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
        lda #0                  ; release IEC bus
        sta serport
        ldx stack
        txs
        cli
delay18:
        cmp ($ea,x)
delay14 = * - 1
delay12:
        rts

; =============================================================================
;
; =============================================================================
drv_recv:
        lda #$08                ; CLK low to signal that we're receiving
        sta serport

        lda serport             ; get EOR mask for data
        asl
        eor serport
        and #$e0
        sta @eor

        lda #$01
:
        bit serport             ; wait for DATA low
        bmi drv_exit
        beq :-

        sei                     ; disable IRQs

        lda #0                  ; release CLK
        sta serport

        lda #$01
:
        bit serport             ; wait for DATA high
        bne :-

; 2 MHz code
        jsr delay14             ; 14

        lda serport             ; get bits 7 and 5
        asl

        jsr delay14             ; 14

        eor serport             ; get bits 6 and 4

        asl
        asl
        asl

        jsr @delay              ; 24
        jsr @delay

        eor serport             ; get 3 and 1

        asl

        jsr delay18             ; 18

        eor serport             ; finally get 2 and 0
@eor = * + 1
        eor #$5e
@delay:
        rts
