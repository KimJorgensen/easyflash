
.importzp   ptr1

.import     eload_recv
.export     _eload_recv_status

.include "config.s"

; =============================================================================
;
; Receive a byte from the drive over the fast protocol. Used internally only.
; void __fastcall__ eload_recv_status(uint8_t* status);
;
; parameters:
;       AX  point to 3 bytes for status
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
_eload_recv_status:
        php                 ; to backup the interrupt flag
        sei

        sta ptr1
        stx ptr1 + 1

        ldy #0              ; get 3 bytes of response
:
        jsr eload_recv
        sta (ptr1), y
        iny
        cpy #3
        bne :-

        plp                 ; to restore the interrupt flag
        rts
