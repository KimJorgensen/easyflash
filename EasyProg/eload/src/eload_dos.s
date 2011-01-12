

.include "kernal.i"


; =============================================================================
;
; Send LISTEN to the current drive and open the secondary address 15.
; The caller can use CIOUT or eload_dos_send_data and finally
; eload_dos_cmd_close.
;
; parameters:
;       -
;
; return:
;       C       flag set when an error occured
;
; changes:
;       A, X, Y
;
; =============================================================================
.export eload_dos_cmd_open
eload_dos_cmd_open:
        lda #$6f            ; open channel 15
        sta SA
send_listen:
        lda FA
        jsr LISTEN
        jsr check_err
        bcs ret_err
        lda SA
        jsr SECOND
        jmp check_err


; =============================================================================
;
; Check ST for an error. If an error has occured, return with C set.
; Overwise with C clear.
;
; parameters:
;       -
;
; return:
;       C flag set when an error occured
;
; changes:
;       A
;
; =============================================================================
check_err:
        sec
        lda ST
        bmi ret_err
        clc
ret_err:
        rts


; =============================================================================
;
; Send data bytes using CIOUT. This can be a file name or a DOS command.
; eload_dos_cmd_open must have been called before.
;
; parameters:
;       A       number of bytes
;       XY      address of bytes (X = low)
;
; return:
;       C       flag set when an error occured
;
; changes:
;       A, Y, FNADR, FNLEN
;
; =============================================================================
.export eload_dos_send_data
eload_dos_send_data:
        jsr SETNAM
        ldy #0
@next:
        lda (FNADR), y
        sta $0600,y
        jsr CIOUT
        jsr check_err
        bcs ret_err
        iny
        cpy FNLEN
        bne @next
        rts


; =============================================================================
;
; Send UNLISTEN to the current drive and close the secondary address 15.
;
; parameters:
;       -
;
; return:
;       C       flag set when an error occured
;
; changes:
;       A, X, Y
;
; =============================================================================
.export eload_dos_cmd_close
eload_dos_cmd_close:
        jsr UNLSN
        lda #$ef                ; close channel 15
        sta SA
        bne send_listen         ; branch always

