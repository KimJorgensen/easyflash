
.importzp   ptr1

.import _ef3usb_fload
.import _ef3usb_fclose

.include "ef3usb_macros.s"
.include "kernal_inc.s"


EASYFLASH_CONTROL = $de02
EASYFLASH_KILL    = $04
EASYFLASH_16K     = $07


.code

; =============================================================================
;
; void usbrx_prg(void);
;
; =============================================================================
.proc   _usbrx_prg
.export _usbrx_prg
_usbrx_prg:
        jsr _ef3usb_fload

        sta $fb
        stx $fc         ; start addr

		; set end addr + 1 to $2d and $ae
        clc
        adc ptr1
        sta $2d
        sta $ae
        txa
        adc ptr1 + 1
        sta $2e
        sta $af

        jmp _ef3usb_fclose
.endproc

; =============================================================================
;
; void usbrx_key(void);
;
; =============================================================================
.proc   _usbrx_key
.export _usbrx_key
_usbrx_key:
        wait_usb_rx_ok
        lda USB_DATA    ; get exactly one byte which is one key pressed

        ldx $c6         ; Number of Characters in Keyboard Buffer queue
        cpx $0289       ; Maximum number of Bytes in Keyboard Buffer
        bcs @full
        sta $0277, x    ; Keyboard Buffer Queue (FIFO)
        inx
        stx $c6         ; Number of Characters in Keyboard Buffer queue
@full:
        rts
.endproc
