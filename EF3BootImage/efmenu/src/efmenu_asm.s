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

.export _setBankChangeMode
.export _waitForNoKey


; I/O address used to select the bank
EASYFLASH_IO_BANK    = $de00

; I/O address for enabling memory configuration, /GAME and /EXROM states
EASYFLASH_IO_CONTROL = $de02

; I/O address to set the cartridge mode
EASYFLASH2_IO_MODE   = $de03

.code

; =============================================================================
;
; Set a flash bank and change to the given cartridge mode.
;
; void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode)
;
; in:
;       bank    bank to be set
;       mode    cartridge mode to be set
; out:
;       Never returns
;
.code
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
; Wait until no key is pressed.
;
; void waitForNoKey(void)
;
; in:
;       -
; out:
;       -
;
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

