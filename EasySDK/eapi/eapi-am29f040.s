;
; EasyFlash
;
; (c) 2009-2010 Thomas 'skoe' Giesel
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
EAPI_ZP_INIT_CODE_BASE   = $4b

; hardware dependend values
AM29F040_NUM_BANKS      = 64
AM29F040_MFR_ID         = $01
AM29F040_DEV_ID         = $a4

EAPI_RAM_CODE           = $df80
EAPI_RAM_SIZE           = 124

* = $c000 - 2
        ; PRG start address
        !word $c000

EAPICodeBase:
        !byte $65, $61, $70, $69        ; signature "EAPI"

        !pet "Am29F040 V0.3"
        !byte 0, 0, 0                   ; 16 bytes, must be 0-terminated

; =============================================================================
;
; EAPIInit: User API: To be called with JSR <load_address> + 20
;
; Read Manufacturer ID and Device ID from the flash chip(s) and check if this
; chip is supported by this driver. Prepare our private RAM for the other
; functions of the driver.
; When this function returns, EasyFlash will be configured to bank in the ROM
; area at $8000..$bfff.
;
; This function calls SEI and restores all Flags except C before it returns.
; Do not call it with D-flag set. $01 must enable both ROM areas.
;
; parameters:
;       -
; return:
;       C   set: Flash chip not supported by this driver
;           clear: Flash chip supported by this driver
;       If C ist clear:
;       A   Device ID
;       X   Manufacturer ID
;       Y   Number of physical banks (64 for Am29F040)
; changes:
;       all registers are changed
;
; =============================================================================
EAPIInit:
        php
        sei
        ; backup ZP space
        lda EAPI_ZP_INIT_CODE_BASE
        sta restoreZP0
        lda EAPI_ZP_INIT_CODE_BASE + 1
        sta restoreZP1

        ; find out our memory address
        lda #$60        ; rts
        sta EAPI_ZP_INIT_CODE_BASE
        jsr EAPI_ZP_INIT_CODE_BASE
initCodeBase = * - 1
        tsx
        lda $100, x
        sta EAPI_ZP_INIT_CODE_BASE + 1
        dex
        lda $100, x
        sta EAPI_ZP_INIT_CODE_BASE
        clc
        bcc initContinue

RAMCode:
        ; This code will be copied to EasyFlash RAM at EAPI_RAM_CODE
        !pseudopc EAPI_RAM_CODE {
RAMContentBegin:
; =============================================================================
; JUMP TABLE (will be updated to be correct)
; =============================================================================
jmpTable:
        jmp EAPIWriteFlash - initCodeBase
        jmp EAPIEraseSector - initCodeBase
        jmp EAPISetBank - initCodeBase
        jmp EAPIGetBank - initCodeBase
        jmp EAPISetPtr - initCodeBase
        jmp EAPISetLen - initCodeBase
        jmp EAPIReadFlashInc - initCodeBase
        jmp EAPIWriteFlashInc - initCodeBase
jmpTableEnd:
; =============================================================================
;
; Internal function
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
ultimaxWrite55XXAA:
            lda #$55
            ldx #$aa
            bne ultimaxWrite
ultimaxWriteXX55:
            ldx #$55
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
; Internal function
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
            ldy #>$8555
            lda #$aa
            jsr ultimaxWriteXX55

            ; cycle 2: write $55 to $2AA
            ldy #>$82aa
            jmp ultimaxWrite55XXAA

; =============================================================================
;
; Internal function
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
            ldy #>$e555
            lda #$aa
            jsr ultimaxWriteXX55

            ; cycle 2: write $55 to $2AA
            ldy #>$e2aa
            jmp ultimaxWrite55XXAA
; =============================================================================
;
; Internal function
;
; Read a byte from the inc-address
;
; =============================================================================
readByteForInc:
EAPI_INC_ADDR_LO = * + 1
EAPI_INC_ADDR_HI = * + 2
            lda $ffff
            rts

; =============================================================================
; Variables
; =============================================================================

EAPI_TMP_VAL1           = * + 0
EAPI_TMP_VAL2           = * + 1
EAPI_TMP_VAL3           = * + 2
EAPI_TMP_VAL4           = * + 3
EAPI_TMP_VAL5           = * + 4
EAPI_SHADOW_BANK        = * + 5 ; copy of current bank number set by the user
EAPI_INC_TYPE           = * + 6 ; type used for EAPIReadFlashInc/EAPIWriteFlashInc
EAPI_LENGTH_LO          = * + 7
EAPI_LENGTH_MED         = * + 8
EAPI_LENGTH_HI          = * + 9
; =============================================================================
RAMContentEnd           = * + 10
        } ; end pseudopc
RAMCodeEnd:

!if RAMContentEnd - RAMContentBegin > EAPI_RAM_SIZE {
    !error "Code too large"
}

!if * - initCodeBase > 256 {
    !error "RAMCode not addressable trough (initCodeBase),y"
}

initContinue:
        ; *** copy some code to EasyFlash private RAM ***
        ; length of data to be copied
        ldx #RAMCodeEnd - RAMCode - 1
        ; offset behind initCodeBase of last byte to be copied
        ldy #RAMCodeEnd - initCodeBase - 1
cidCopyCode:
        lda (EAPI_ZP_INIT_CODE_BASE),y
        sta EAPI_RAM_CODE, x
        cmp EAPI_RAM_CODE, x
        bne ciNotSupportedNoReset   ; check if there's really RAM at this address
        dey
        dex
        bpl cidCopyCode

        ; *** calculate jump table ***
        ldx #0
        ldy #(jmpTableEnd - jmpTable) / 3
cidFillJMP:
        inx
        clc
        lda jmpTable, x
        adc EAPI_ZP_INIT_CODE_BASE
        sta jmpTable, x
        inx
        lda jmpTable, x
        adc EAPI_ZP_INIT_CODE_BASE + 1
        sta jmpTable, x
        inx
        dey
        bne cidFillJMP
        
        ; restore the caller's ZP state
restoreZP0 = * + 1
        lda #0
        sta EAPI_ZP_INIT_CODE_BASE
restoreZP1 = * + 1
        lda #0
        sta EAPI_ZP_INIT_CODE_BASE + 1

        ;clc
        bcc ciSkip

ciNotSupportedNoReset:
        sec
        bcs returnOnly
ciNotSupported:
        sec
        bcs resetAndReturn

ciSkip:
        ; check for Am29F040 first, HIROM
        jsr prepareWriteHigh

        ; cycle 3: write $90 to $555
        ldy #>$e555
        lda #$90
        jsr ultimaxWriteXX55

        ; offset 0: Manufacturer ID (we're on bank 0)
        lda $a000
        sta EAPI_TMP_VAL1

        ; offset 1: Device ID
        lda $a001
        sta EAPI_TMP_VAL2

        ; check for Am29F040 first, LOROM
        jsr prepareWriteLow

        ; cycle 3: write $90 to $555
        ldy #>$8555
        lda #$90
        jsr ultimaxWriteXX55

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

        ; everything okay
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
returnOnly:
        lda EAPI_TMP_VAL2       ; device in A
        ldx EAPI_TMP_VAL1       ; manufacturer in X
        ldy #AM29F040_NUM_BANKS ; number of banks in Y

        bcs returnCSet
        plp
        clc
        rts
returnCSet:
        plp
        sec
        rts


; =============================================================================
;
; EAPIWriteFlash: User API: To be called with JSR jmpTable + 0
;
; Write a byte to the given address. The address must be as seen in Ultimax
; mode, i.e. do not use the base addresses $8000 or $a000 but $8000 or $e000.
;
; When writing to flash memory only bits containing a '1' can be changed to
; contain a '0'. Trying to change memory bits from '0' to '1' will result in
; an error. You must erase a memory block to get '1' bits.
;
; This function calls SEI and restores all Flags except C before it returns.
; Do not call it with D-flag set. $01 must enable the affected ROM area.
; It can only be used after having called EAPIInit.
;
; parameters:
;       A   value
;       XY  address (X = low), $8xxx/$9xxx or $Exxx/$Fxxx
;
; return:
;       C   set: Error
;           clear: Okay
; changes:
;       Z,N <- value
;
; =============================================================================
EAPIWriteFlash:
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL2
        sty EAPI_TMP_VAL3
        php
        sei

        ; address lower than $E000?
        cpy #$e0
        bcc writeLow

        jsr prepareWriteHigh

        ; cycle 3: write $A0 to $555
        ldy #>$e555
        bne write_common    ; always

writeLow:
        jsr prepareWriteLow

        ; cycle 3: write $A0 to $555
        ldy #>$8555

write_common:
        lda #$a0
        jsr ultimaxWriteXX55

        ; now we have to activate the right bank
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK

        ; cycle 4: write data
        lda EAPI_TMP_VAL1
        ldx EAPI_TMP_VAL2
        ldy EAPI_TMP_VAL3
        jsr ultimaxWrite

        ; that's it

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

        plp
        sec ; error
        bcs ret

retOk:
        plp
        clc
ret:
        ldy EAPI_TMP_VAL3
        ldx EAPI_TMP_VAL2
        lda EAPI_TMP_VAL1
        rts


; =============================================================================
;
; Trampoline
;
; =============================================================================

checkProgress2:
        bcc checkProgress ; always

; =============================================================================
;
; EAPIEraseSector: User API: To be called with JSR jmpTable + 3
;
; Erase the sector at the given address. The bank number currently set and the
; address together must point to the first byte of a 64 kByte sector.
;
; When erasing a sector, all bits of the 64 KiB area will be set to '1'.
; This means that 8 banks with 8 KiB each will be erased, all of them either
; in the LOROM chip when $8000 is used or in the HIROM chip when $e000 is
; used.
;
; This function calls SEI and restores all flags except C before it returns.
; Do not call it with D-flag set. $01 must enable the affected ROM area.
; It can only be used after having called EAPIInit.
;
; parameters:
;       A   bank
;       Y   base address (high byte), $80 for LOROM, $a0 or $e0 for HIROM
;
; return:
;       C   set: Error
;           clear: Okay
;
; change:
;       -
;
; =============================================================================
EAPIEraseSector:
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL2
        sty EAPI_TMP_VAL3
        php
        sei

        ; address lower than $E000?
        cpy #$e0
        bcc selow

        jsr prepareWriteHigh

        ; cycle 3: write $80 to $555
        ldy #>$e555
        lda #$80
        jsr ultimaxWriteXX55

        ; cycle 4: write $AA to $555
        ; ldy #>$e555 <= unchanged
        lda #$aa
        jsr ultimaxWriteXX55

        ; cycle 5: write $55 to $2AA
        ldy #>$e2aa
        bne secommon    ; always

selow:
        jsr prepareWriteLow

        ; cycle 3: write $80 to $555
        ldy #>$8555
        lda #$80
        jsr ultimaxWriteXX55

        ; cycle 4: write $AA to $555
        ; ldy #>$8555 <= unchanged
        lda #$aa
        jsr ultimaxWriteXX55

        ; cycle 5: write $55 to $2AA
        ldy #>$82aa

secommon:
        jsr ultimaxWrite55XXAA

        ; activate the right bank
        lda EAPI_TMP_VAL1
        sta EASYFLASH_IO_BANK

        ; cycle 6: write $30 to base + SA
        ldx #$00
        ldy EAPI_TMP_VAL3
        cpy #$a0
        bne seskip
        ldy #$e0
seskip:
        lda #$30
        jsr ultimaxWrite

        ; wait > 50 us before checking progress (=> datasheet)
        ldx #10
sewait:
        dex
        bne sewait
        
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK
        
        ; (Y is unchanged after ldy)
        clc
        bcc checkProgress2 ; always

; =============================================================================
;
; EAPISetBank: User API: To be called with JSR jmpTable + 6
;
; Set the bank. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; This function can only be used after having called EAPIInit.
;
; parameters:
;       A   bank
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
EAPISetBank:
        sta EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK
        rts


; =============================================================================
;
; EAPIGetBank: User API: To be called with JSR jmpTable + 9
;
; Get the selected bank which has been set with EAPISetBank.
; Note that the current bank number can not be read back using the hardware
; register $de00 directly, this function uses a mirror of that register in RAM.
;
; This function can only be used after having called EAPIInit.

; parameters:
;       -
;
; return:
;       A  bank
;
; changes:
;       Z,N <- bank
;
; =============================================================================
EAPIGetBank:
        lda EAPI_SHADOW_BANK
        rts


; =============================================================================
;
; EAPISetPtr: User API: To be called with JSR jmpTable + 12
;
; Set the pointer for EAPIReadFlashInc/EAPIWriteFlashInc
;
; This function can only be used after having called EAPIInit.
;
; parameters:
;       A   bank mode, where to continue at the end of a bank
;           $D0: 00:0:1FFF=>00:1:0000, 00:1:1FFF=>01:0:1FFF (lhlh...)
;           $B0: 00:0:1FFF=>01:0:0000 (llll...)
;           $D4: 00:1:1FFF=>01:1:0000 (hhhh...)
;       XY  address (X = low) address must be in range $8000-$bfff
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
EAPISetPtr:
        sta EAPI_INC_TYPE
        stx EAPI_INC_ADDR_LO
        sty EAPI_INC_ADDR_HI
        rts


; =============================================================================
;
; EAPISetLen: User API: To be called with JSR jmpTable + 15
;
; - sets the length for EAPIReadFlashInc
;
; This function can only be used after having called EAPIInit.
;
; parameters:
;       AXY length (X = low, Y = med, A = high)
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
EAPISetLen:
        sta EAPI_LENGTH_HI
        stx EAPI_LENGTH_LO
        sty EAPI_LENGTH_MED
        rts


; =============================================================================
;
; EAPIReadFlashInc: User API: To be called with JSR jmpTable + 18
;
; Read a byte from the current pointer from EasyFlash flash memory.
; Increment the pointer according to the current bank wrap strategy.
; Pointer and wrap strategy have been set by a call to EAPISetPtr.
;
; The number of bytes to be read may be set by calling EAPISetLen.
; EOF will be set if the length is zero, otherwise it will be decremented.
; Even when EOF is delivered a new byte has been read and the pointer 
; incremented. This means the use of EAPISetLen is optional.
;
; parameters:
;       -
;
; return:
;       A   value
;       C   set if EOF
;
; changes:
;       Z,N <- value
;
; =============================================================================
EAPIReadFlashInc:
        ; now we have to activate the right bank
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK

        ; make sure that the write routine jumps back to us
        lda #$00
        sta EAPI_TMP_VAL3

        ; call the read-routine
        jsr readByteForInc
        
        ; remember the result & x/y registers
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL4
        sty EAPI_TMP_VAL5
        
        ; inc address
        clc
        bcc readInc_inc

readInc_Length:
        ; decrement length
        lda EAPI_LENGTH_LO
        bne nomed
        lda EAPI_LENGTH_MED
        bne nohi
        lda EAPI_LENGTH_HI
        beq eof
        dec EAPI_LENGTH_HI
nohi:
        dec EAPI_LENGTH_MED
nomed:
        dec EAPI_LENGTH_LO
        clc ; no EOF

return:
        ldy EAPI_TMP_VAL5
        ldx EAPI_TMP_VAL4
        lda EAPI_TMP_VAL1
        rts

eof:
        sec ; EOF
        bcs return

; =============================================================================
;
; EAPIWriteFlashInc: User API: To be called with JSR jmpTable + 21
;
; Write a byte to the current pointer to EasyFlash flash memory.
; Increment the pointer according to the current bank wrap strategy.
; Pointer and wrap strategy have been set by a call to EAPISetPtr.
;
; In case of an error the position is not inc'ed.
;
; parameters:
;       A   value
;
; return:
;       C   set: Error
;           clear: Okay
; changes:
;       Z,N <- value
;
; =============================================================================
EAPIWriteFlashInc:
        ; store X/Y
        sta EAPI_TMP_VAL1
        stx EAPI_TMP_VAL4
        sty EAPI_TMP_VAL5
        
        ; load address to store to
        ldx EAPI_INC_ADDR_LO
        lda EAPI_INC_ADDR_HI
        cmp #$a0
        bcs writeInc_skip
        ; clc
        adc #$40 ; ora #$40 would do so, but adc is more intuitive
writeInc_skip:
        tay
        lda EAPI_TMP_VAL1

        ; write to flash
        jsr jmpTable + 0
        bcs writeInc_error
        
        ; the increment code is used by both functions
readInc_inc:
        ; inc to next position
        inc EAPI_INC_ADDR_LO
        bne rwInc_noInc
        
        ; inc page
        inc EAPI_INC_ADDR_HI
        lda EAPI_INC_TYPE
        and #$e0
        cmp EAPI_INC_ADDR_HI
        bne rwInc_noInc
        ; inc bank
        lda EAPI_INC_TYPE
        asl
        asl
        asl
        sta EAPI_INC_ADDR_HI
        inc EAPI_SHADOW_BANK
        
rwInc_noInc:
        clc
        ; jump back to the read-routine, it has set EAPI_TMP_VAL3 to zero
        ; for write: EAPI_TMP_VAL3 ist set by EAPIWriteFlash to the hi-address (never zero)
        lda EAPI_TMP_VAL3
        beq readInc_Length
writeInc_error:
        ldy EAPI_TMP_VAL5
        ldx EAPI_TMP_VAL4
        lda EAPI_TMP_VAL1
        rts


