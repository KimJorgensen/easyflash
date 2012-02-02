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

.include "kernal.s"

.importzp       sp, sreg, regsave
.importzp       tmp1, tmp2, tmp3
.importzp       ptr1

.import eload_dos_close
.import eload_set_read_byte_fn
.import eload_read_byte_from_buffer
.import eload_read_byte_kernal
.import eload_read_byte_fast
.import eload_buffered_byte
.import eload_send

.import _eload_prepare_drive


.bss

; remaining number of bytes in this sector
.export eload_ctr
eload_ctr:
        .res 1

.code

; =============================================================================
;
; Open the file for read access.
;
; int __fastcall__ eload_open_read(const char* name);
;
; parameters:
;       pointer to name in AX (A = low)
;
; return:
;       result in AX (A = low), 0 = okay, -1 = error
;
; =============================================================================
        .export _eload_open_read
_eload_open_read:
        sta ptr1
        stx ptr1 + 1
        lda #0
        sta ST                  ; set status to OK
        lda $ba                 ; set drive to listen
        jsr LISTEN
        lda #$f0                ; open + secondary addr 0
        jsr SECOND

        ldy #0
@send_name:
        lda (ptr1),y            ; send file name
        beq @end_name           ; 0-termination
        jsr CIOUT
        iny
        bne @send_name          ; branch always (usually)
@end_name:
        jsr UNLSN

        ; give up if we couldn't even send the file name
        lda ST
        bne @fail

        ; Check if the file is readable
        lda $ba
        jsr TALK
        lda #$60                ; talk + secondary addr 0
        jsr TKSA
        jsr ACPTR               ; read a byte
        sta eload_buffered_byte       ; keep it for later
        jsr UNTLK

        lda ST
        bne @close_and_fail

        jsr _eload_prepare_drive
        bcs @use_kernal

        lda #<eload_read_byte_fast
        ldx #>eload_read_byte_fast
        jsr eload_set_read_byte_fn

        ; todo: sollte das nicht schon raus können?
        ldx #0
@delay:
        dex
        bne @delay

        lda #1                  ; command: load
        jsr eload_send
        jsr eload_recv         ; status / number of bytes

        sta eload_ctr
        cmp #$ff
        beq @close_and_fail
        bne @ok

@use_kernal:
        ; no suitable speeder found, use Kernal
        lda #<eload_read_byte_from_buffer
        ldx #>eload_read_byte_from_buffer
        jsr eload_set_read_byte_fn

        ; send TALK so we can read the bytes afterwards
        lda $ba
        jsr TALK
        lda #$60
        jsr TKSA
@ok:
        lda #0
        tax
        rts

@close_and_fail:
        lda #0                  ; channel 0
        sta SA
        jsr eload_dos_close
@fail:
        lda #$ff
        tax
        rts

; =============================================================================
;
; Receive a byte from the drive over the fast protocol. Used internally only.
;
; parameters:
;       -
;
; return:
;       Byte in A, Z-flag according to A
;
; changes:
;       flags
;
; =============================================================================
.export eload_recv
eload_recv:
        ; $dd00: | D_in | C_in | D_out | C_out || A_out | RS232 | VIC | VIC |
        ; Note about the timing: After 50 cycles a PAL C64 is about 1 cycle
        ; slower than the drive, an NTSC C64 is about 1 cycle faster. As we
        ; have a safety gap of about 2 us, this doesn't matter.

        ; Handshake Step 1: Drive signals byte ready with DATA low
@wait1:
        lda $dd00
        bmi @wait1

        sei

@eload_recv_waitbadline:
        lda $d011               ; wait until a badline won't screw up
        clc                     ; the timing
        sbc $d012
        and #7
        beq @eload_recv_waitbadline

        ; Handshake Step 2: Host sets CLK low to acknowledge
        lda $dd00
        ora #$10
        sta $dd00               ; [1]

        ; Handshake Step 3: Host releases CLK - Time base
        bit $ff                 ; waste 3 cycles
        and #$03
        ; an 1 MHz drive sees this 6..12 us after [1], so we have dt = 9
        sta $dd00               ; t = 0
        sta @eor+1              ; 4

        nop
        nop
        nop
        nop
        nop                     ; 14

        ; receive bits
        lda $dd00               ; 18 - b0 b1
        lsr
        lsr
        eor $dd00               ; 26 - b2 b3
        lsr
        lsr
        eor $dd00               ; 34 - b4 b5
        lsr
        lsr
@eor:
        eor #$00
        eor $dd00               ; 44 - b6 b7
        cli
        rts

