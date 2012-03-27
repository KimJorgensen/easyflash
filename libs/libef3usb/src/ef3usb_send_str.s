

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa, popax


.include "ef3usb_macros.s"


; =============================================================================
;
; void __fastcall__ ef3usb_send_str(const char* p);
;
; Send the string at p to USB. Stop at the 0 termination or after 255 chars.
; In any case a 0-termination is sent.
;
; =============================================================================
.proc   _ef3usb_send_str
.export _ef3usb_send_str
_ef3usb_send_str:
        sta ptr1
        stx ptr1 + 1            ; Save p

        ldy #0
@byteLoop:
        lda (ptr1), y
        beq @end
        wait_usb_tx_ok
        sta USB_DATA

        iny
        bne @byteLoop
@end:
        wait_usb_tx_ok
        lda #0
        sta USB_DATA
        rts
.endproc
