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

; I/O address used to select the bank
EASYFLASH_IO_BANK    = $de00

; I/O address for enabling memory configuration, /GAME and /EXROM states
EASYFLASH_IO_CONTROL = $de02

; I/O address to set the cartridge mode
EASYFLASH2_IO_MODE   = $de03

.code

; =============================================================================
;
; Set the EF ROM bank.
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
; void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode)
;
; in:
;       bank    bank to be set
;       mode    cartridge mode to be set
; out:
;       Never returns
;
.export _setBankChangeMode
_setBankChangeMode:
        sta tmp2    ; 2nd argument
        jsr popa    ; 1st argument
        sta tmp1

        ldx #sbcmCodeEnd - sbcmCode
sbcmCopy:
        ; copy code on stack
        lda sbcmCode, x
        sta $0100, x
        dex
        bpl sbcmCopy
        jmp $0100

        ; the following code will be run at $0100
sbcmCode:
        lda tmp1
        sta EASYFLASH_IO_BANK
        lda tmp2
        sta EASYFLASH2_IO_MODE
        ; we don't pass here normally
        clc
sbcmWait:
        dec $d020
        bcc sbcmWait
sbcmCodeEnd:


; =============================================================================
;
; Set the EF ROM bank, copy 16k to 0x0801 and run that program by jumping to
; 0x080d.
;
; The program in flash contains two byte start address, we ignore it and skip
; these two bytes. That's why the copy starts from $8002.
;
;
; void __fastcall__ startProgram(uint8_t bank);
;
; in:
;       bank    bank to be set
; out:
;       Never returns
;
.export _startProgram
_startProgram:
        sta EASYFLASH_IO_BANK
        lda #EASYFLASH_16K
        sta EASYFLASH_IO_CONTROL
        ldx #$00
:
        lda startProgramCode,x
        sta $c000,x
        dex
        bne :-
        jmp $c000
startProgramCode:
.org $c000
        ldy #16 * 4
        ldx #0
@loop:
@i1:
        lda $8002,x
@i2:
        sta $0801,x
        inx
        bne @loop
        inc @i1 + 2
        inc @i2 + 2
        dey
        bne @loop

        jsr $ff84   ; Initialise I/O
        jsr $ff8a   ; Restore Kernal Vectors
        jsr $ff81   ; Initialize screen editor
        jmp $080d
.reloc

; =============================================================================
;
; Wait until no key is pressed.
;
; void waitForNoKey(void)
;
; in:
;       -
; out:
;       -
;
.export _waitForNoKey
_waitForNoKey:
        ; Prepare the CIA to scan the keyboard
        ldx #$00
        sta $dc00       ; Port A: pull down all rows
        stx $dc03       ; DDRB $00 = input
        dex
        stx $dc02       ; DDRA $ff = output (X is still $ff from copy loop)
wfnk:
        lda $dc01
        cmp #$ff        ; still a key pressed?
        bne wfnk
        rts

