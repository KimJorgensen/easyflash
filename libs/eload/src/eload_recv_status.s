
.import eload_recv
.export _eload_recv_status

.include "config.s"

; =============================================================================
;
; Receive a byte from the drive over the fast protocol. Used internally only.
; uint8_t eload_recv_status(void);
;
; parameters:
;       -
;
; return:
;       A   Status byte
;       X   0
;
; changes:
;       -
;
; =============================================================================
_eload_recv_status:
        php                 ; to backup the interrupt flag
        sei

        jsr eload_recv
        ldx #0

        plp                 ; to restore the interrupt flag
        rts
