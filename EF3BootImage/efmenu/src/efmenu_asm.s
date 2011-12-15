;
; (c) 2010 Thomas Giesel
;
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;
; Thomas Giesel skoe@directbox.com
;

.include "c64.inc"
.include "memcfg.inc"

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa

EASYFLASH_16K        = $07
EASYFLASH_KILL       = $04

MODE_EF_NO_RESET     = $01

; I/O address used to select the bank
EASYFLASH_IO_BANK    = $de00

; I/O address used to select the slot
EASYFLASH_IO_SLOT    = $de01

; I/O address for enabling memory configuration, /GAME and /EXROM states
EASYFLASH_IO_CONTROL = $de02

; I/O address to set the KERNAL bank
EASYFLASH3_IO_KERNAL_BANK   = $de0e

; I/O address to set the cartridge mode
EASYFLASH3_IO_MODE          = $de0f

.code

; =============================================================================
;
; Set the EF slot.
;
; void __fastcall__ set_slot(uint8_t slot)
;
; in:
;       slot    slot to be set
; out:
;       -
;
.export _set_slot
_set_slot:
        sta EASYFLASH_IO_SLOT
        rts

; =============================================================================
;
; Set the EF bank.
;
; void __fastcall__ set_bank(uint8_t bank)
;
; in:
;       bank    bank to be set
; out:
;       -
;
.export _set_bank
_set_bank:
        sta EASYFLASH_IO_BANK
        rts

; =============================================================================
;
; Set the EF ROM bank and change to the given cartridge mode.
;
; void __fastcall__ set_bank_change_mode(uint8_t bank, uint8_t mode)
;
; in:
;       bank    bank to be set
;       mode    cartridge mode to be set
; out:
;       Never returns
;
.export _set_bank_change_mode
_set_bank_change_mode:
        sta tmp2    ; 2nd argument
        jsr popa    ; 1st argument
        sta tmp1

        sei
        ldx #sbcm_codeEnd - sbcm_code
sbcm_copy:
        ; copy code on stack
        lda sbcm_code, x
        sta $0100, x
        dex
        bpl sbcm_copy
        jmp $0100

sbcm_code:
.org $0100
        ; the following code will be run at $0100
        lda tmp1
        sta EASYFLASH_IO_BANK
        sta EASYFLASH3_IO_KERNAL_BANK

        lda tmp2
        sta EASYFLASH3_IO_MODE
        ; we don't pass here normally
sbcm_wait:
        dec $d020
        jmp sbcm_wait
.reloc
sbcm_codeEnd:


; =============================================================================
;
; Set the EF ROM bank, copy 16k to 0x0801 and run that program by jumping to
; 0x080d.
;
; The program in flash contains two byte start address, we ignore it and skip
; these two bytes. That's why the copy starts from $8002.
;
;
; void __fastcall__ start_program(uint8_t bank);
;
; in:
;       bank    bank to be set
; out:
;       Never returns
;
.export _start_program
_start_program:
        pha
        lda #MODE_EF_NO_RESET
        sta EASYFLASH3_IO_MODE          ; hides the mode register
        lda #EASYFLASH_16K
        sta EASYFLASH_IO_CONTROL
        ldx #$00
:
        lda start_program_code,x
        sta $c000,x
        dex
        bne :-
        pla
        sta start_program_bank
        jmp $c000
start_program_code:
.org $c000
        sei
        ldy #32 * 4             ; number of blocks to copy
        ldx #0
start_program_bank = * + 1
@loop:
        lda #0
        sta EASYFLASH_IO_BANK
@copy:
@i1:
        lda $8002
@i2:
        sta $0801
        inc @i2 + 1
        bne @nhi
        inc @i2 + 2
@nhi:
        inc @i1 + 1
        bne @copy
        inc @i1 + 2
        lda @i1 + 2
        cmp #$c0
        bne @noBankInc
        inc start_program_bank
        lda #$80
        sta @i1 + 2
@noBankInc:
        dey
        bne @loop

        lda #EASYFLASH_KILL
        sta EASYFLASH_IO_CONTROL

        jsr $ff84   ; Initialise I/O
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor

        jmp $080d
.reloc

; =============================================================================
;
; Wait until no key is pressed.
;
; void wait_for_no_key(void)
;
; in:
;       -
; out:
;       -
;
.export _wait_for_no_key
_wait_for_no_key:
        ; Prepare the CIA to scan the keyboard
        ldx #$00
        stx $dc00       ; Port A: pull down all rows
        stx $dc03       ; DDRB $00 = input
        dex
        stx $dc02       ; DDRA $ff = output (X is still $ff from copy loop)
wfnk:
        lda $dc01
        cmp #$ff        ; still a key pressed?
        bne wfnk
        rts

