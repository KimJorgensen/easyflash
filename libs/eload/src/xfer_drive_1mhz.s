 ;
 ; ELoad
 ;
 ; (c) 2011 Thomas Giesel
 ; transfer code based on work by Per Olofsson
 ;
 ; This software is provided 'as-is', without any express or implied
 ; warranty.  In no event will the authors be held liable for any damages
 ; arising from the use of this software.
 ;
 ; Permission is granted to anyone to use this software for any purpose,
 ; including commercial applications, and to alter it and redistribute it
 ; freely, subject to the following restrictions:
 ;
 ; 1. The origin of this software must not be misrepresented; you must not
 ;    claim that you wrote the original software. If you use this software
 ;    in a product, an acknowledgment in the product documentation would be
 ;    appreciated but is not required.
 ; 2. Altered source versions must be plainly marked as such, and must not be
 ;    misrepresented as being the original software.
 ; 3. This notice may not be removed or altered from any source distribution.
 ;
 ; Thomas Giesel skoe@directbox.com
 ;

; =============================================================================
;
; Signal with CLK low that we are ready and wait until the C64 signals that it
; wants to send data. Return after SEI.
;
; Exit the drive code on ATN.
;
; changes:
;       A
;
; =============================================================================
drv_wait_rx:
        lda #$08                ; CLK low to signal that we're receiving
        sta serport

        lda #$01
:
        bit serport             ; wait for DATA low
        bmi @exit               ; exit if ATN goes low
        beq :-
        sei
        rts
@exit:
        jmp drv_exit

; =============================================================================
;
; Send a data to the host. The first byte will be taken from the highest
; address.
;
; parameters:
;       AX      point to buffer
;       Y       number of bytes (1 to 256=0)
;
; return:
;       Y = #$ff
;
; changes:
;       A, X, Y, zptmp
;
; =============================================================================
; serport: | A_in | DEV | DEV | ACK_out || C_out | C_in | D_out | D_in |
;
; bit pair timing           11111111112222222222333333333344444444445555555555
; (us)            012345678901234567890123456789012345678901234567890123456789
; Drive write     S       B       B             B         B           XX
; PAL read         ssssss   bbbbbb  bbbbbb          bbbbbb    bbbbbb
; NTSC read        ssssss   bbbbbb  bbbbb         bbbbbb    bbbbbb

drv_send:
        sta buff_ptr
        stx buff_ptr + 1
        dey

@next_byte:
        ; Handshake Step 1: Drive signals data ready with DATA low
        lda #$02                ; 49
        sta serport             ; 53

        ; Handshake Step 2: Host sets CLK low when ready
        lda #$04                ; 55
:
        bit serport             ; wait for CLK low (that's 1!)
        bmi exit_1              ; leave the drive code if ATN is active
        beq :-                  ; This loop takes 9 cycles

        lda (buff_ptr), y

        ; Handshake Step 3: Drive releases DATA to start
        ldx #$00
        stx serport

        tax                     ; 2
        and #$0f                ; 4
        sta serport             ; 8     b3 b1 (CLK DATA)

        asl                     ; 10
        and #$0f                ; 12
        sta serport             ; 16    b2 b0

        txa
        lsr
        lsr
        lsr
        lsr                     ; 26
        sta serport             ; 30    b7 b5

        asl                     ; 32
        and #$0f                ; 34
        nop                     ; 36
        sta serport             ; 40    b6 b4

        dey                     ; 42
        cpy #$ff                ; 44
        bne @next_byte          ; 46/47
@ret:
        lda #0                  ; 48
        sta serport             ; 52    set CLK and DATA high

        rts

exit_1:
        jmp drv_exit


; =============================================================================
;
; Receive 2 * 256 bytes of drive code to $0300
;
; =============================================================================
drv_load_code:
        ldx #>$0300
        bne drv_load_code_common ; always

; =============================================================================
;
; Receive 2 * 256 bytes of overlay code to $0500
;
; =============================================================================
drv_load_overlay:
        ldx #>$0500
drv_load_code_common:
        lda #0                  ; low byte of address
        tay                     ; number of bytes (256)
        jsr recv                ; 1st block
        inc buff_ptr + 1
        jsr recv_to_ptr         ; 2nd block
        rts

; =============================================================================
;
; Load Y bytes to AX. The first byte will be stored to the highest
; address.
;
; parameters:
;       Y           number of bytes (1 to 256=0)
;
; return:
;       buff_ptr    set to AX
;       A           last byte transfered
;       Y           0
;
; changes:
;       A, X, Y
;
; Returns with I-flag set (SEI).
;
; =============================================================================
recv_to_buffer:
        lda #<buffer
        ldx #>buffer
recv:
        sta buff_ptr
        stx buff_ptr + 1
recv_to_ptr:
        jsr drv_wait_rx         ; does SEI

        ; initialize recv code
        lda serport
        and #$60                ; <= needed?
        asl
        eor serport
        and #$e0
        sta eor_correction

        lda #0                  ; release CLK
        sta serport

; =============================================================================
.if eload_use_fast_tx = 0

@next_byte:
        lda #$08                ; CLK low to signal that we're receiving
        sta serport

        lda #$01
:
        bit serport             ; wait for DATA low
        bmi exit_1
        beq :-

        sei

        lda #0                  ; release CLK
        sta serport

        lda #$01
:
        bit serport             ; wait for DATA high
        bne :-                  ; t = 3..9

        nop
        nop                     ;  7..
        lda serport             ; 11..17    get bits 7 and 5

        asl
        nop
        nop                     ; 17..
        eor serport             ; 21..27    get bits 6 and 4

        asl
        asl
        asl                     ; 27..
        nop
        nop
        nop                     ; 33..
        eor serport             ; 37..43    get bits 3 and 1

        asl
        eor eor_correction      ; 43..      not on zeropage (abs addressing)
        eor serport             ; 47..53    get bits 2 and 0

        dey
        sta (buff_ptr), y
        bne @next_byte

        rts
; =============================================================================
.else ; eload_use_fast_tx
;                                                    .
; bit pair timing           11111111112222222222333333333344444444445555555555
; (us)            012345678901234567890123456789012345678901234567890123456789
; PAL write       S       7         6         3          2           X
;                         5         4         1          0
; NTSC write      S       7         6         3        2           X
;                         5         4         1        0

; drive read       ssssss    777777    666666    333333    222222

@next_byte:
        lda #$01                ; 54..
:
        bit serport             ;           wait for DATA high
        bne :-                  ; t = 3..9

        nop
        nop                     ;  7..
        lda serport             ; 11..17    get bits 7 and 5

        asl
        nop
        nop                     ; 17..
        eor serport             ; 21..27    get bits 6 and 4

        asl
        asl
        asl                     ; 27..
        eor serport             ; 31..37    get bits 3 and 1

        asl
        eor eor_correction      ; 37..      not on zeropage (abs addressing)
        eor serport             ; 41..47    get bits 2 and 0

        dey                     ; 43..
        sta (buff_ptr), y       ; 49..

        bne @next_byte          ; 52*..
        rts
.endif
