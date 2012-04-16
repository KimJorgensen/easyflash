
.importzp   ptr1

.import _ef3usb_fload
.import _ef3usb_fclose

.include "ef3usb_macros.s"


EASYFLASH_CONTROL = $de02
EASYFLASH_KILL    = $04
EASYFLASH_16K     = $07

start_addr = $fb

.code
; =============================================================================
;
; void usbtool_prg_load_and_run(void);
;
; =============================================================================
.proc   _usbtool_prg_load_and_run
.export _usbtool_prg_load_and_run
_usbtool_prg_load_and_run:
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
