;
; EasyFlash
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


; I/O address used to select the bank
EASYFLASH_IO_BANK    = $de00

; I/O address for enabling memory configuration, /GAME and /EXROM states
EASYFLASH_IO_CONTROL = $de02

; Bit for Expansion Port /GAME line (1 = low)
EASYFLASH_IO_BIT_GAME    = $01

; Bit for Expansion Port /EXROM line (1 = low)
EASYFLASH_IO_BIT_EXROM   = $02

; Bit for memory control (1 = enabled)
EASYFLASH_IO_BIT_MEMCTRL = $04

; Bit for status LED (1 = on)
EASYFLASH_IO_BIT_LED     = $80

FLASH_ALG_ERROR_BIT      = $20

; There's a pointer to our code base
EAPI_ZP_REAL_CODE_BASE  = $14

; hardware dependend values
AM29F040_NUM_BANKS      = 64
AM29F040_MFR_ID         = $01
AM29F040_DEV_ID         = $a4

EAPI_PRIVATE_RAM        = $df80
EAPI_RAM_CODE           = $df80 ; 80 bytes
EAPI_TMP_VAL1           = $dfd0
EAPI_TMP_VAL2           = $dfd1
EAPI_TMP_VAL3           = $dfd2
EAPI_SHADOW_BANK        = $dfd6 ; copy of bank number set by the user

; space for 4 * JMP xxxx = 12 bytes
EAPI_NUM_FNS            = 4
EAPI_JUMP_TABLE         = $dfe0

* = $c000 - 2

        ; PRG start address
        !byte $00, $c0
EAPICodeBase:

        ; “EAPI”
        !byte $65, $61, $70, $69

; =============================================================================
;
; Read Manufacturer ID and Device ID from the chip at the given address
; and check if this chip is supported by this driver.
; Prepare our private RAM for the other functions of the driver.
; When this function returns, EasyFlash will be configured to bank in the ROM
; area at $8000..$bfff.
;
; This function calls SEI/CLI.
;
; parameters:
;       -
; return:
;       C   set: Flash chip not supported by this driver
;           clear: Flash chip supported by this driver
;       If C ist clear:
;       A   Device ID
;       X   Manufacturer ID
;       Y   Number of banks (currently 64)
;
; =============================================================================
EAPICheckIds:
        ; *** copy some code to EasyFlash private RAM ***
        ; length of data to be copied
        ldx #CopyToRAMCodeEnd - CopyToRAMCode - 1
        ; offset of last byte to be copied
        ldy #CopyToRAMCodeEnd - EAPICodeBase - 1 - 256
        ; this code is at the end of our code, add 256 bytes to the pointer
        inc EAPI_ZP_REAL_CODE_BASE + 1
cidCopyCode:
        lda (EAPI_ZP_REAL_CODE_BASE),y
        sta EAPI_RAM_CODE,x
        cmp EAPI_RAM_CODE,x
        bne ciNotSupported      ; check if there's really RAM at this address
        dey
        dex
        bpl cidCopyCode

        ; restore original value
        dec EAPI_ZP_REAL_CODE_BASE + 1

        ; *** fill the jump table with the opcode of JMP ***
        ldx #EAPI_NUM_FNS * 3
        lda #$4c
cidFillJMP:
        sta EAPI_JUMP_TABLE - 1, x
        dex
        bne cidFillJMP

        ; *** calculate jump table ***
        clc
        lda #<EAPIWriteFlash - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE
        sta EAPI_JUMP_TABLE + 1 + 0 * 3
        lda #>EAPIWriteFlash - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE + 1
        sta EAPI_JUMP_TABLE + 2 + 0 * 3

        ;clc
        lda #<EAPIEraseSector - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE
        sta EAPI_JUMP_TABLE + 1 + 1 * 3
        lda #>EAPIEraseSector - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE + 1
        sta EAPI_JUMP_TABLE + 2 + 1 * 3

        ;clc
        lda #<EAPISetBank - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE
        sta EAPI_JUMP_TABLE + 1 + 2 * 3
        lda #>EAPISetBank - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE + 1
        sta EAPI_JUMP_TABLE + 2 + 2 * 3

        ;clc
        lda #<EAPIGetBank - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE
        sta EAPI_JUMP_TABLE + 1 + 3 * 3
        lda #>EAPIGetBank - EAPICodeBase
        adc EAPI_ZP_REAL_CODE_BASE + 1
        sta EAPI_JUMP_TABLE + 2 + 3 * 3

        sei

        ;clc
        bcc ciSkip

ciNotSupported:
        sec
        bcs resetAndReturn

ciSkip:

        ; check for Am29F040 first, HIROM
        jsr prepareWriteHigh

        ; cycle 3: write $90 to $555
        ldx #<$e555
        ldy #>$e555
        lda #$90
        jsr ultimaxWrite

        ; offset 0: Manufacturer ID (we're on bank 0)
        lda $a000
        sta EAPI_TMP_VAL1

        ; offset 1: Device ID
        lda $a001
        sta EAPI_TMP_VAL2

        ; check for Am29F040 first, LOROM
        jsr prepareWriteLow

        ; cycle 3: write $90 to $555
        ldx #<$8555
        ldy #>$8555
        lda #$90
        jsr ultimaxWrite

        ; offset 0: Manufacturer ID (we're on bank 0)
        ldx $8000
        ; must be the same as at HIROM
        cpx EAPI_TMP_VAL1
        bne ciNotSupported

        ; offset 1: Device ID
        lda $8001
        ; must be the same as at HIROM
        cmp EAPI_TMP_VAL2
        bne ciNotSupported

        ; check if it is an Am29F040
        cpx #AM29F040_MFR_ID
        bne ciNotSupported
        cmp #AM29F040_DEV_ID
        bne ciNotSupported

        clc

resetAndReturn:
        ; reset flash chip: write $F0 to any address
        ; ldx #<$e000 - don't care
        ldy #>$e000
        lda #$f0
        jsr ultimaxWrite

        ; ldx #<$8000 - don't care
        ldy #>$8000
        lda #$f0
        jsr ultimaxWrite

        cli
        lda EAPI_TMP_VAL2       ; device in A
        ldx EAPI_TMP_VAL1       ; manufacturer in X
        ldy #AM29F040_NUM_BANKS
        rts


; =============================================================================
;
; Write a byte to the given address.
;
; This is done in background by the chip, the caller should check the progress
; using EAPICheckProgress.
;
; This function calls SEI/CLI.
;
; parameters:
;       A   value
;       XY  address (X = low), $8xxx/$9xxx or $Exxx/$Fxxx
;
; return:
;       C   set: Error
;           clear: Okay
;
; =============================================================================
EAPIWriteFlash:
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL2
        sty EAPI_TMP_VAL3
        sei

        ; address lower than $E000?
        cpy #$e0
        bcc writeLow

        jsr prepareWriteHigh

        ; cycle 3: write $A0 to $555
        ldx #<$e555
        ldy #>$e555
        bne write_common    ; always

writeLow:
        jsr prepareWriteLow

        ; cycle 3: write $A0 to $555
        ldx #<$8555
        ldy #>$8555

write_common:
        lda #$a0
        jsr ultimaxWrite

        ; now we have to activate the right bank
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK

        ; cycle 4: write data
        lda EAPI_TMP_VAL1
        ldx EAPI_TMP_VAL2
        ldy EAPI_TMP_VAL3
        jsr ultimaxWrite

        ; that's it
        cli

checkProgress:
        cpy #$e0
        bcs checkProgressHi
        ; check progress of flash memory at $8000

        ; wait as long as the toggle bit toggles
checkProgressLo:
        lda $8000
        cmp $8000
        bne cpLoDifferent
        ; read once more to catch the case status => data
        cmp $8000
        beq retOk
cpLoDifferent:
        ; check if the error bit is set
        and #FLASH_ALG_ERROR_BIT
        ; wait longer if not
        beq checkProgressLo
        bne resetFlash

checkProgressHi:
        ; same code for $e000 (we're not in Ultimax mode, use $a000)
        ; wait as long as the toggle bit toggles
        lda $a000
        cmp $a000
        bne cpHiDifferent
        ; read once more to catch the case status => data
        cmp $a000
        beq retOk
cpHiDifferent:
        ; check if the error bit is set
        and #FLASH_ALG_ERROR_BIT
        ; wait longer if not
        beq checkProgressHi

resetFlash:
        ; lda #<$8000 - don't care
        ldy #>$8000
        lda #$f0
        jsr ultimaxWrite

        ; lda #<$e000 - don't care
        ldy #>$e000
        lda #$f0
        jsr ultimaxWrite

        sec ; error
        bcs ret

retOk:
        clc
ret:
        lda EAPI_TMP_VAL1
        ldx EAPI_TMP_VAL2
        ldy EAPI_TMP_VAL3
        rts


; =============================================================================
;
; Trampoline
;
; =============================================================================

checkProgress2:
        bcc checkProgress

; =============================================================================
;
; Erase the sector at the given address. The bank number currently set and the
; address together must point to the first byte of a 64 kByte sector.
;
; This operation is done in background by the chip, the caller should check
; the progress using EAPICheckProgress.
;
; This function calls SEI/CLI.
;
; parameters:
;       base in XY (X = low), $8000 or $E000
;
; return:
;       -
;
; change:
;       -
;
; =============================================================================
EAPIEraseSector:
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL2
        sty EAPI_TMP_VAL3
        sei

        ; address lower than $E000?
        cpy #$e0
        bcc selow

        jsr prepareWriteHigh

        ; cycle 3: write $80 to $555
        ldx #<$e555
        ldy #>$e555
        lda #$80
        jsr ultimaxWrite

        ; cycle 4: write $AA to $555
        ldx #<$e555
        ldy #>$e555
        lda #$aa
        jsr ultimaxWrite

        ; cycle 5: write $55 to $2AA
        ldx #<$e2aa
        ldy #>$e2aa
        bne secommon    ; always

selow:
        jsr prepareWriteLow

        ; cycle 3: write $80 to $555
        ldx #<$8555
        ldy #>$8555
        lda #$80
        jsr ultimaxWrite

        ; cycle 4: write $AA to $555
        ldx #<$8555
        ldy #>$8555
        lda #$aa
        jsr ultimaxWrite

        ; cycle 5: write $55 to $2AA
        ldx #<$82aa
        ldy #>$82aa

secommon:
        lda #$55
        jsr ultimaxWrite

        ; activate the right bank
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK

        ; cycle 6: write $30 to base + SA
        ldx EAPI_TMP_VAL2
        ldy EAPI_TMP_VAL3
        lda #$30
        jsr ultimaxWrite

        ; (Y is unchanged after ldy)
        cli
        clc
        bcc checkProgress2

; =============================================================================
;
; Set the bank. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; parameters:
;       bank in XY (X = low, currently 0..63; Y = high, currently 0)
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
EAPISetBank:
        stx EAPI_SHADOW_BANK
        stx EASYFLASH_IO_BANK
        rts


; =============================================================================
;
; Get the selected bank.
;
; parameters:
;       -
;
; return:
;       bank in XY (X = low, currently 0..63; Y = high, currently 0)
;
; changes:
;       -
;
; =============================================================================
EAPIGetBank:
        ldx EAPI_SHADOW_BANK
        ldy #0
        rts

; =============================================================================
;
; 1. Turn on Ultimax mode and LED
; 2. Write byte to address
; 3. Turn off Ultimax mode and LED
;    (show 16k of current bank at $8000..$BFFF)
;
; Remember that the address must be based on $8000 for LOROM or
; $E000 for HIROM! Der caller may want to SEI.
;
; Parameters:
;           A   Value
;           XY  Address (X = low)
; Changes:
;           X
;
; =============================================================================
CopyToRAMCode:
        !pseudopc EAPI_RAM_CODE {
ultimaxWrite:
            stx uwDest
            sty uwDest + 1
            ; /GAME low, /EXROM high, LED on
            ldx #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_LED
            stx EASYFLASH_IO_CONTROL
uwDest = * + 1
            sta $ffff           ; will be modified

            ; /GAME low, /EXROM low, LED off
            ldx #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_EXROM
            stx EASYFLASH_IO_CONTROL
            rts

; =============================================================================
;
; Set bank 0, send command cycles 1 and 2.
; Do this for the LOROM flash chip which is visible at $8000.
;
; =============================================================================
prepareWriteLow:
            ; select bank 0
            lda #0
            sta EASYFLASH_IO_BANK

            ; cycle 1: write $AA to $555
            ldx #<$8555
            ldy #>$8555
            lda #$aa
            jsr ultimaxWrite

            ; cycle 2: write $55 to $2AA
            ldx #<$82aa
            ldy #>$82aa
            lda #$55
            jmp ultimaxWrite


; =============================================================================
;
; Set bank 0, send command cycles 1 and 2.
; Do this for the HIROM flash chip which is visible at $e000 in Ultimax mode.
;
; =============================================================================
prepareWriteHigh:
            ; select bank 0
            lda #0
            sta EASYFLASH_IO_BANK

            ; cycle 1: write $AA to $555
            ldx #<$e555
            ldy #>$e555
            lda #$aa
            jsr ultimaxWrite

            ; cycle 2: write $55 to $2AA
            ldx #<$e2aa
            ldy #>$e2aa
            lda #$55
            jmp ultimaxWrite
        } ; end pseudopc
CopyToRAMCodeEnd:

!if CopyToRAMCodeEnd - CopyToRAMCode > 80 {
    !error "Code too large"
}
