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
.export _usbReadFile
_usbReadFile:
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
