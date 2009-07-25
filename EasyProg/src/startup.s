;
; EasyFlash - startup.s - Start-up code for stand-alone cartridges (acme)
;
; (c) 2009 Thomas 'skoe' Giesel
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

; This code runs in Ultimax mode after reset, so this memory becomes
; visible at $E000..$FFFF first and must contain a reset vector

* = $ff80

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_KILL    = $04

startBank:
        ; this must be the 1st byte in this code, so it's easy to patch it from outside
        !byte 0

startConfig:
        ; this must be the 2nd byte in this code, so it's easy to patch it from outside
        !byte 0

startUpCode:
        !pseudopc $0002 {
            ; === this code is copied to the ZP, does some inits ===
            ; === scans the keyboard and kills the cartridge or  ===
            ; === starts the main cartridge                      ===

            ; leave the Ultimax mode
            ; otherwise the MAX detection would always find a MAX...
            lda #EASYFLASH_KILL | EASYFLASH_LED
            sta EASYFLASH_CONTROL

            ; Check if we are on a real MAX / VC-10 by reading/writing RAM
            lda #$a5    ; quite unprobable to appear accidently on the bus
            sta $c000
            cmp $c000
            bne startCart ; different => MAX => skip keyboard check

            ; Prepare the CIA to scan the keyboard
            lda #$7f
            sta $dc00   ; pull down row 7 (DPA)

            ldx #$ff
            stx $dc02   ; DDRA $ff = output (X is still $ff from copy loop)
            inx
            stx $dc03   ; DDRB $00 = input

            ; Read the keys pressed on this row
            lda $dc01   ; read coloumns (DPB)

            ; Restore CIA registers to the state after (hard) reset
            stx $dc02   ; DDRA input again
            stx $dc00   ; Now row pulled down

            ; Check if one of the magic kill keys was pressed
            and #$e0    ; only leave "Run/Stop", "Q" and "C="
            cmp #$e0
            bne kill    ; branch if one of these keys is pressed
startCart:
            ; start the cartridge code on the right bank
patchStartBank = * + 1
            lda #0      ; start bank will be put here
            sta EASYFLASH_BANK
patchStartConfig = * + 1
            lda #0      ; start config will be put here
            !byte $2c   ; skip next instruction
kill:
            lda #EASYFLASH_KILL
reset:
            sta EASYFLASH_CONTROL
            jmp ($fffc) ; reset
        }
startUpEnd:

coldStart:
        ; === the reset vector points here ===
        sei
        ldx #$ff
        txs
        cld

        ; Wait to make sure RESET is deasserted on all chips and write
        ; to RAM to make sure it started up correctly (=> RAM datasheets)
startWait:
        sta $0100, x
        dex
        bne startWait

        ; copy the final start-up code to RAM (zero page)
        ldx #(startUpEnd - startUpCode)
l1:
        lda startUpCode, x
        sta $02, x
        dex
        bpl l1
        lda startConfig
        sta patchStartConfig
        lda startBank
        sta patchStartBank

        jmp $0002

        ; fill it up to $FFFA to put the vectors there
        !align $ffff, $fffa, $ff

        !word reti        ; NMI
        !word coldStart   ; RESET

        ; we don't need the IRQ vector an can put RTI here to save space :)
reti:
        rti
        !byte 0xff
