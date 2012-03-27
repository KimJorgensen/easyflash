
.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa, popax

.import _ef3usb_fload
.import _ef3usb_fclose

.include "ef3usb_macros.s"


EASYFLASH_CONTROL = $de02
EASYFLASH_KILL    = $04
EASYFLASH_16K     = $07

trampoline = $0100

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

        sta start_addr
        stx start_addr + 1

		; set end addr + 1 to $2d and $ae
        clc
        adc ptr1
        sta $2d
        sta $ae
        txa
        adc ptr1 + 1
        sta $2e
        sta $af

        jsr _ef3usb_fclose

        ; start the program
        ; looks like BASIC?
        lda start_addr
        ldx start_addr + 1
        cmp #<$0801
        bne @no_basic
        cpx #>$0801
        bne @no_basic

        ; === start basic ===
        ldx #basic_starter_end - basic_starter
:
        lda basic_starter, x
        sta trampoline, x
        dex
        bpl :-
        bmi @run_it

        ; === start machine code ===
@no_basic:
        ldx #asm_starter_end - asm_starter
:
        lda asm_starter, x
        sta trampoline, x
        dex
        bpl :-

        lda start_addr
        sta trampoline_jmp_addr + 1
        lda start_addr + 1
        sta trampoline_jmp_addr + 2
@run_it:
        lda #EASYFLASH_KILL
        jmp trampoline
.endproc

; =============================================================================
basic_starter:
.org trampoline
        sta EASYFLASH_CONTROL

        ; These may not be needed - depending on what you'll do
;        jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

        ; for BASIC programs
        jsr $E453     ; Initialize Vectors
        jsr $E3BF     ; Initialize BASIC RAM

        ;lda #$37
        ;sta $01
        jsr $a659        ; Basic-Zeiger setzen und CLR
        jmp $a7ae        ; Interpreterschleife (RUN)
.reloc
basic_starter_end:

; =============================================================================
asm_starter:
.org trampoline
        sta EASYFLASH_CONTROL

        ; These may not be needed - depending on what you'll do
        ;jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

        ; for BASIC programs
        jsr $E453     ; Initialize Vectors
        jsr $E3BF     ; Initialize BASIC RAM

        ;lda #$37
        ;sta $01
trampoline_jmp_addr:
        jmp $beef
.reloc
asm_starter_end:
