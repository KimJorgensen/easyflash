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
        stx @storeAddr + 2      ; Save buffer address

        ldx ptr1
        ldy ptr1 + 1
        wait_usb_tx_ok          ; request bytes (from XY)
        stx USB_DATA
        wait_usb_tx_ok
        sty USB_DATA

        ; get number of bytes actually there
        ; todo: we should check if this is more than we asked for
        wait_usb_rx_ok
        ldx USB_DATA            ; low byte
        stx ptr2                ; xfer size in ptr2
        wait_usb_rx_ok
        ldy USB_DATA            ; high byte
        sty ptr2 + 1            ; xfer size in ptr2
        bne @loadCont
        cpx #0                  ; check for EOF
        beq @end                ; 0 bytes == EOF
@loadCont:
        txa
        eor #$ff
        tax
        tya
        eor #$ff
        tay                     ; calc -size - 1
        jmp @incCounter         ; inc to get -size

@getBytes:
        ; xy contains number of bytes to be xfered (x = low byte)
        wait_usb_rx_ok
        lda USB_DATA
@storeAddr:
        sta $beef
        inc @storeAddr + 1
        bne @incCounter
        inc @storeAddr + 2
@incCounter:
        inx
        bne @getBytes
        iny
        bne @getBytes
@end:
        lda ptr2
        ldx ptr2 + 1            ; return number of bytes transfered
        rts
.endproc


; =============================================================================
;
; void usbCloseFile(void);
;
; =============================================================================
.proc   _usbCloseFile
.export _usbCloseFile
_usbCloseFile:
        lda #0
        wait_usb_tx_ok
        sta USB_DATA
        wait_usb_tx_ok
        sta USB_DATA
.endproc
