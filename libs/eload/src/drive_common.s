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

.include "eload_macros.s"

gcr_overflow_size = 69
gcr_overflow_buff = $01bb

; =============================================================================
;
; load file
; args: start track, start sector
; returns: $00 for EOF, $ff for error, $01-$fe for each data block
;
; =============================================================================
load:
        ldx prev_file_track
        lda prev_file_sect
loadchain:
@sendsector:
        jsr drv_readsector
        bcc :+
        lda #$ff                ; send read error
        jmp error
:
        ldx #254                ; send 254 bytes (full sector)
        lda buffer              ; last sector?
        bne :+
        ldx buffer + 1          ; send number of bytes in sector (1-254)
        dex
:
        stx @buflen
        txa
        jsr drv_send           ; send byte count

        ldx #0                  ; send data
@send:
        txa
        pha
        lda buffer + 2,x
        jsr drv_send
        pla
        tax
        inx
@buflen = * + 1
        cpx #$ff
        bne @send

        ; load next t/s in chain into x/a or exit loop if EOF
        ldx buffer
        beq @done
        lda buffer + 1
        jmp @sendsector
@done:
        lda #0
        jmp senddone

; =============================================================================
;
; =============================================================================
drv_main:
        cli                     ; allow IRQs when waiting
        jsr drv_wait_rx

        ldy #1
        jsr drv_recv_to_buffer  ; get command byte

        cmp #1                  ; load a file
        beq load

        cmp #4
        beq write_sector

        lda #$ff                ; unknown command
senddone:
error:
        jsr drv_send
        jmp drv_main

; =============================================================================
;
; Used in all versions of the send function
;
; =============================================================================
drv_sendtbl:
        ; 0 0 0 0 b0 b2 b1 b3
        .byte $0f, $07, $0d, $05
        .byte $0b, $03, $09, $01
        .byte $0e, $06, $0c, $04
        .byte $0a, $02, $08, $00

; =============================================================================
write_sector: ; 05db
        ldy #2
        lda #<job_track         ; receive track and secor
        ldx #>job_track
        jsr drv_recv

        ; receive 69 + 256 bytes of GCR encodec track
        ldy #gcr_overflow_size
        lda #<gcr_overflow_buff
        ldx #>gcr_overflow_buff
        jsr drv_recv            ; 69 bytes
        jsr drv_recv_to_buffer  ; 256 bytes (Y = 0 from prev call)

        ldx job_track
        lda job_sector
        jsr drv_writesector
        bcs @ret
        lda #ELOAD_OK
@ret:
        jmp senddone        ; send OK or error
