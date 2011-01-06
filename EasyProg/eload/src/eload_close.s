

.include "kernal.i"

.import _eload_drive_is_fast


; =============================================================================
;
; void eload_close(void);
;
; Close the current file and cancel the drive code, if any.
;
; =============================================================================
.export _eload_close
_eload_close:
        jsr _eload_drive_is_fast
        beq @close_kernal

        ; First cancel the drive code
        lda $dd00
        ora #$08                ; ATN low
        sta $dd00
        ldx #10
:
        dex
        bne :-
        and #$07
        sta $dd00               ; ATN high

@close_kernal:
        ; Close file
        jsr UNTLK
        lda $ba                 ; set drive to listen
        jsr LISTEN
        lda #$e0                ; close + channel 0
        jsr SECOND
        jmp UNLSN
