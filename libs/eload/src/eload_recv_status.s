
.import     eload_recv

.include "config.s"

; =============================================================================
;
; Receive 3 bytes status message from the drive
; void __fastcall__ eload_recv_status(uint8_t* status);
;
; parameters:
;       AX  point to 3 bytes for status
;
; return:
;       -
;
; changes:
;       Y
;
; =============================================================================
.export _eload_recv_status
_eload_recv_status:
        php                 ; to backup the interrupt flag
        sei

        ldy #3              ; get 3 bytes of response
        jsr eload_recv

        plp                 ; to restore the interrupt flag
        rts
