;
; (c) 2010 Thomas Giesel
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

.include "c64.inc"

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa, popax

USB_ID     = $de08
USB_STATUS = $de09
USB_DATA   = $de0a


.code


; =============================================================================
;
; =============================================================================
.macro wait_usb_tx_ok
:
        bit USB_STATUS
        bvc :-
.endmacro


; =============================================================================
;
; =============================================================================
.macro wait_usb_rx_ok
:
        bit USB_STATUS
        bpl :-
.endmacro


; =============================================================================
;
; Discard all data from the USB RX buffer.
;
; void __fastcall__ usbDiscardBuffer(void)
;
; in:
;       -
; out:
;       -
;
.export _usbDiscardBuffer
_usbDiscardBuffer:
        ldx #0
:
        lda USB_DATA
        dex
        bne :-
        rts

; =============================================================================
;
; unsigned int __fastcall__ usbReadFile(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from USB to "buffer".
; Returns the number of bytes actually read, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
.proc   _usbReadFile
.export _usbReadFile
_usbReadFile:
        sta ptr1
        stx ptr1 + 1            ; Save size

        jsr popax
        sta @storeAddr + 1
        stx @storeAddr + 2      ; Save buffer

        lda #0
        sta ptr3
        sta ptr3 + 1            ; 0 bytes transfered so far

@loadLoop:
        ; still bytes to load?
        lda ptr3 + 1
        cmp ptr1 + 1
        bne @LoadCont
        lda ptr3
        cmp ptr1
        beq @end
@LoadCont:
        ldx #0                  ; prepare XY = 256
        ldy #1
        lda ptr1 + 1            ; At least 256 bytes remaining?
        bne @atLeast256Needed
        ldx ptr1                ; XY = rest (less than 256)
        ldy #0
@atLeast256Needed:
        wait_usb_tx_ok          ; request 1..256 bytes (from XY)
        stx USB_DATA
        wait_usb_tx_ok
        sty USB_DATA

        ; get number of bytes actually there
        ; todo: we should check if this is more than we asked for
        wait_usb_rx_ok
        lda USB_DATA            ; low byte
        sta ptr2                ; xfer size in ptr2
        clc
        adc ptr3                ; add to bytes transfered so far
        sta ptr3
        wait_usb_rx_ok
        lda USB_DATA            ; high byte
        sta ptr2 + 1            ; xfer size in ptr2
        adc ptr3 + 1            ; add to bytes transfered so far
        sta ptr3 + 1

        ; subtract xfer size from remaining size
        sec
        lda ptr1
        sbc ptr2
        sta ptr1
        lda ptr1 + 1
        sbc ptr2 + 1
        sta ptr1 + 1

        ; todo: optimize the following lines
        ldx ptr2
        ldy ptr2 + 1            ; get xfer size

        cpy #1                  ; high byte == 1 means 256 bytes
        beq @getBytes           ; (low byte == 0 in this case)
        cpx #0
        beq @end                ; 0 bytes == EOF
@getBytes:
        ; x contains number of bytes to be xfered (low byte)
        wait_usb_rx_ok
        lda USB_DATA
@storeAddr:
        sta $eeee
        inc @storeAddr + 1
        bne :+
        inc @storeAddr + 2
:
        dex
        bne @getBytes
@end:
        lda ptr3
        ldx ptr3 + 1            ; return number of bytes transfered
        rts


.if 1 = 0
        ; check for 256 bytes
        cpx #1
        bne @not256
        cmp #0
        bne @not256

        ; optimized case: 256 bytes
        ; =========================
        jsr popax
        sta ptr2
        stx ptr2 + 1            ; Save buffer

        ldy #0                  ; bytesread = 0
@Loop1:
        bit USB_STATUS
        bpl @Loop1
        lda USB_DATA

        ;cpx #0
        ;bne @End               ; EOF
        sta (ptr2), y           ; Save read byte

        iny
        bne @Loop1

        lda #0
        ldx #1                  ; return bytesread
        rts

        ; =========================
@not256:
        eor #$ff
        sta ptr1
        txa
        eor #$ff
        sta ptr1 + 1            ; Save -size-1

        jsr popax
        sta ptr2
        stx ptr2 + 1            ; Save buffer

        lda #$00                ; bytesread = 0
        sta ptr3
        sta ptr3 + 1
        beq @Read3              ; Branch always

@Loop:
        bit USB_STATUS
        bpl @Loop
        lda USB_DATA

        ldx #0
        ;cpx #0
        ;bne @End                ; EOF
        sta (ptr2, x)           ; Save read byte

        inc ptr2
        bne @Read2
        inc ptr2 + 1            ; ++buffer;
@Read2:
        inc ptr3
        bne @Read3
        inc ptr3 + 1            ; ++bytesread;
@Read3:
        inc ptr1
        bne @Loop
        inc ptr1 + 1
        bne @Loop
@End:
        lda ptr3
        ldx ptr3 + 1            ; return bytesread;

        rts
.endif
.endproc
