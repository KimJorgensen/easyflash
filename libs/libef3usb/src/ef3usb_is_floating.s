

.include "ef3usb_macros.s"

; =============================================================================
;
; uint8_t ef3usb_is_floating(void);
;
; Check if there is no RX ready line but the data lines change nevertheless.
; This means that at least one data line is floating. In this case the jumpers
; may be in the wrong position.
;
; Return 0 if the lines are floating, >0 if not (or if we can't detect it
; because real data is waiting).
;
; =============================================================================
.proc   _ef3usb_is_floating
.export _ef3usb_is_floating
_ef3usb_is_floating:
        ldy #0
@check_more:
        bit USB_STATUS
        bmi @rx_waiting
        ldx USB_DATA
        cpx USB_DATA
        bne @floating
        dey
        bne @check_more
@rx_waiting: ; or not floating
        lda #0
        tax
        rts

@floating:
        lda #1
        tax
        rts
.endproc
