;
; EasyFlash
;
; (c) 2009-2010 Thomas 'skoe' Giesel
;
; Modified for SST39SF040 by ALeX Kazik
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

!source "eapi_defs.s"

; There's a pointer to our code base
EAPI_ZP_INIT_CODE_BASE   = $4b

; hardware dependend values
SST39SF040_NUM_BANKS     = 64
SST39SF040_MFR_ID        = $bf
SST39SF040_DEV_ID        = $b7

EAPI_RAM_CODE            = $df80
EAPI_RAM_SIZE            = 124

* = $c000 - 2
        ; PRG start address
        !word $c000

EAPICodeBase:
        !byte $65, $61, $70, $69        ; signature "EAPI"

        !pet "SST39SF040 V1.0"
        !byte 0                   ; 16 bytes, must be 0-terminated

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
; This function calls SEI, it restores all Flags except C before it returns.
; Do not call it with D-flag set. $01 must enable both ROM areas.
;
; parameters:
;       -
; return:
;       C   set: Flash chip not supported by this driver
;           clear: Flash chip supported by this driver
;       If C is clear:
;       A   Device ID
;       X   Manufacturer ID
;       Y   Number of physical banks (>= 64) or
;           number of slots (< 64) with 64 banks each
;       If C is set:
;       A   Error reason
; changes:
;       all registers are changed
;
; =============================================================================
EAPIInit:
        php
        sei
        ; backup ZP space
        lda EAPI_ZP_INIT_CODE_BASE
        pha
        lda EAPI_ZP_INIT_CODE_BASE + 1
        pha

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
        jmp EAPISetSlot - initCodeBase
        jmp EAPIGetSlot - initCodeBase
jmpTableEnd:

; =============================================================================
;
; Internal function
;
; Switch to Ultimax mode, write a byte to flash (complete write sequence),
; return to normal mode.
;
; Must not change the C flag!
;
; Parameters:
;           A = EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME |
;               EASYFLASH_IO_BIT_LED
;           X = $aa
;           Y = $02
; Changes:
;           X
; Return:
;           A = value which has been written
;
; =============================================================================

writeByte:
            ; /GAME low, /EXROM high, LED on
            sta EASYFLASH_IO_CONTROL

            ; cycle 1: write $AA to $05555 (02:*:1555)
            sty EASYFLASH_IO_BANK
EAPI_WRITE_MAGIC1_HI = * + 2
            stx $ff55           ; hi byte will be modified

            ; cycle 2: write $55 to $02AAA (01:*:0AAA)
            lda #$01
            sta EASYFLASH_IO_BANK
            lda #$55
EAPI_WRITE_MAGIC2_HI = * + 2
            sta $ffaa           ; hi byte will be modified

            ; cycle 3: write $A0 to $05555 (02:*:1555)
            sty EASYFLASH_IO_BANK
            lda #$a0
EAPI_WRITE_MAGIC3_HI = * + 2
            sta $ff55           ; hi byte will be modified

            ; cycle 4: write BA to ADDRESS
            lda EAPI_SHADOW_BANK
            sta EASYFLASH_IO_BANK

EAPI_WRITE_VAL = * + 1
            lda #00             ; will be modified
EAPI_WRITE_ADDR_LO = * + 1
EAPI_WRITE_ADDR_HI = * + 2
            sta $ffff           ; will be modified
exitUltimax:
            ; /GAME low, /EXROM low, LED off
            ldx #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_EXROM
            stx EASYFLASH_IO_CONTROL
            rts

; =============================================================================
;
; Internal function
;
; 1. Turn on Ultimax mode and LED
; 2. Write byte to address
; 3. Turn off Ultimax mode and LED
;    (show 16k of current bank at $8000..$BFFF)
;
; The caller may want to SEI.
;
; Parameters:
;           A   Address(HI)
;               $95 for $05555, LOROM (02:0:1555)
;               $8a for $02AAA, LOROM (01:0:0aaa)
;               $f5 for $05555, HIROM (02:1:1555)
;               $ea for $02AAA, HIROM (01:1:0aaa)
;           Y   Value
; Changes:
;           X
;
; =============================================================================
ultimaxWrite05555:
            ldx #$02
            stx EASYFLASH_IO_BANK
            ldx #$55
            bne ultimaxWrite
ultimaxWrite02AAA:
            ldx #$01
            stx EASYFLASH_IO_BANK
            ldx #$AA

; =============================================================================
;
; Internal function
;
; 1. Turn on Ultimax mode and LED
; 2. Write byte to address
; 3. Turn off Ultimax mode and LED
;    (show 16k of current bank at $8000..$BFFF)
;
; The bank must be already set. The caller may want to SEI.
;
; Parameters:
;           XA  Address (X = low), $8xxx/$9xxx or $Exxx/$Fxxx
;           Y   Value
; Changes:
;           X
;
; =============================================================================
ultimaxWrite:
            stx uwDest
            sta uwDest + 1
            ; /GAME low, /EXROM high, LED on
            ldx #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_LED
            stx EASYFLASH_IO_CONTROL
uwDest = * + 1
            sty $ffff           ; will be modified
            jmp exitUltimax

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
;
; Internal function
;
; Used for progress check. Compare A with the value from (YX).
;
; =============================================================================
cmpByte:                            ;  6  6 (JSR)
EAPI_CMP_BYTE_ADDR_LO = * + 1
EAPI_CMP_BYTE_ADDR_HI = * + 2
            cmp $ffff               ; +4 10
            rts                     ; +6 25

; =============================================================================
; Variables
; =============================================================================

EAPI_TMP_VAL1           = * + 0
EAPI_TMP_VAL2           = * + 1
EAPI_SHADOW_BANK        = * + 2 ; copy of current bank number set by the user
EAPI_INC_TYPE           = * + 3 ; type used for EAPIReadFlashInc/EAPIWriteFlashInc
EAPI_LENGTH_LO          = * + 4
EAPI_LENGTH_MED         = * + 5
EAPI_LENGTH_HI          = * + 6
; =============================================================================
RAMContentEnd           = * + 7
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
        cmp EAPI_RAM_CODE, x    ; check if there's really RAM at this address
        bne ciRamError
        dey
        dex
        bpl cidCopyCode

        ; *** calculate jump table ***
        ldx #0
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
        cpx #jmpTableEnd - jmpTable
        bne cidFillJMP
        clc
        bcc ciNoRamError
ciRamError:
        lda #EAPI_ERR_RAM
        sta EAPI_WRITE_ADDR_LO
        sec                     ; error
ciNoRamError:
        ; restore the caller's ZP state
        pla
        sta EAPI_ZP_INIT_CODE_BASE + 1
        pla
        sta EAPI_ZP_INIT_CODE_BASE
        bcs returnOnlyTrampoline ; branch on error from above

        ; check for SST39SF040, ROMH/ROML
        ; cycle 1: write $AA to $05555 (02:*:1555)
        ldy #$aa
        lda #$f5
        jsr ultimaxWrite05555
        lda #$95
        jsr ultimaxWrite05555

        ; cycle 2: write $55 to $02AAA (01:*:0aaa)
        ldy #$55
        lda #$ea
        jsr ultimaxWrite02AAA
        lda #$8a
        jsr ultimaxWrite02AAA

        ; cycle 3: write $90 to $05555 (02:*:1555)
        ldy #$90
        lda #$f5
        jsr ultimaxWrite05555
        lda #$95
        jsr ultimaxWrite05555

        ; offset 0: Manufacturer ID (we're on bank 0)
        ; offset 1: Device ID
        lda $a000
        sta EAPI_TMP_VAL2
        ldx $a001
        stx EAPI_WRITE_ADDR_LO

        cmp #SST39SF040_MFR_ID
        bne ciROMHNotSupported
        cpx #SST39SF040_DEV_ID
        bne ciROMHNotSupported
        beq ciCheckLow

returnOnlyTrampoline:
        bcs returnOnly

ciCheckLow:
        ; check for SST39SF040, ROML
        ; offset 0: Manufacturer ID (we're on bank 0)
        ; offset 1: Device ID
        lda $8000
        ldx $8001

        cmp #SST39SF040_MFR_ID
        bne ciROMLNotSupported
        cpx #SST39SF040_DEV_ID
        bne ciROMLNotSupported

        ; everything okay
        clc
        bcc resetAndReturn

ciROMLNotSupported:
        lda #EAPI_ERR_ROML
        bne ciSaveErrorAndReturn

ciROMHNotSupported:
        lda #EAPI_ERR_ROMH

ciSaveErrorAndReturn:
        sta EAPI_WRITE_ADDR_LO  ; error code in A
        sec

resetAndReturn:                 ; C indicates error
        lda #0
        sta EASYFLASH_IO_BANK   ; restore it for compatibility to old versions

        ; reset flash chip: write $F0 to any address
        ; ldx #<$8000 - don't care
        lda #>$8000
        ldy #$f0
        jsr ultimaxWrite

        ; ldx #<$e000 - don't care
        lda #>$e000
        ; ldy #$f0 - still loaded
        jsr ultimaxWrite

returnOnly:                     ; C indicates error
        lda EAPI_WRITE_ADDR_LO  ; device or error code in A
        bcs returnCSet
        ldx EAPI_TMP_VAL2       ; manufacturer in X
        ldy #SST39SF040_NUM_BANKS ; number of banks in Y

        plp
        clc                     ; do this after plp :)
        rts
returnCSet:
        plp
        sec                     ; do this after plp :)
        rts

; =============================================================================
;
; EAPIWriteFlash: User API: To be called with JSR jmpTable + 0 = $df80
;
; Write a byte to the given address. The address must be as seen in Ultimax
; mode, i.e. do not use the base addresses $8000 or $a000 but $8000 or $e000.
;
; When writing to flash memory only bits containing a '1' can be changed to
; contain a '0'. Trying to change memory bits from '0' to '1' will result in
; an error. You must erase a memory block to get '1' bits.
;
; This function uses SEI, it restores all flags except C before it returns.
; Do not call it with D-flag set. $01 must enable both ROM areas.
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
        sta EAPI_WRITE_VAL
        stx EAPI_WRITE_ADDR_LO
        stx EAPI_CMP_BYTE_ADDR_LO
        sty EAPI_WRITE_ADDR_HI
        php
        sei

        tya
        and #$bf            ; $ex => $ax
        sta EAPI_CMP_BYTE_ADDR_HI
        
        tya
        and #$e0            ; remove address bits within the bank

        eor #$00 XOR $15
        sta EAPI_WRITE_MAGIC1_HI
        sta EAPI_WRITE_MAGIC3_HI

        eor #$15 XOR $0a
        sta EAPI_WRITE_MAGIC2_HI

        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_LED
        ldx #$aa
        ldy #$02
        jsr writeByte

        ; that's it, check result
        ; EAPI_WRITE_VAL still in A
wcpLoop:
        jsr cmpByte
        beq wcheckOK
        dey
        bne wcpLoop
        ; Time out and/or error
        clc
        bcc resetFlash
wcheckOK:
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK
        clc
        bcc retOk

; =============================================================================
;
; EAPIEraseSector: User API: To be called with JSR jmpTable + 3 = $df83
;
; Erase the sector at the given address. The bank number currently set and the
; address together must point to the first byte of a 64 kByte sector.
;
; When erasing a sector, all bits of the 64 KiB area will be set to '1'.
; This means that 8 banks with 8 KiB each will be erased, all of them either
; in the LOROM chip when $8000 is used or in the HIROM chip when $e000 is
; used.
;
; This function uses SEI, it restores all flags except C before it returns.
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
;       Z,N <- bank
;
; =============================================================================
EAPIEraseSector:
        sta EAPI_TMP_VAL1       ; used for bank number
        sta EAPI_WRITE_VAL      ; backup of A only
        stx EAPI_WRITE_ADDR_LO  ; backup of X only, no parameter
        sty EAPI_WRITE_ADDR_HI
        php
        sei

seloop:
        ldy EAPI_WRITE_ADDR_HI
        tya
        cpy #$80
        beq seskip
        lda #$e0            ; HIROM (Ultimax mode)
        ldy #$a0            ; HIROM (16K mode)
seskip:
        sty EAPI_CMP_BYTE_ADDR_HI

        ; cycle 1: write $AA to $05555 (02:*:1555)
        ldy #$aa
        eor #$00 XOR $15
        jsr ultimaxWrite05555

        ; cycle 2: write $55 to $02AAA (01:*:0AAA)
        ldy #$55
        eor #$15 XOR $0a
        jsr ultimaxWrite02AAA

        ; cycle 3: write $80 to $05555 (02:*:1555)
        ldy #$80
        eor #$0a XOR $15
        jsr ultimaxWrite05555

        ; cycle 4: write $AA to $05555 (02:*:1555)
        ldy #$aa
        jsr ultimaxWrite05555

        ; cycle 5: write $55 to $02AAA (01:*:0AAA)
        ldy #$55
        eor #$15 XOR $0a
        jsr ultimaxWrite02AAA

        ; activate the right bank
        ldx EAPI_TMP_VAL1
        stx EASYFLASH_IO_BANK

        ; cycle 6: write $30 to base + SA
        ldx #$00
        stx EAPI_CMP_BYTE_ADDR_LO
        eor #$0a XOR $00
        ldy EAPI_TMP_VAL1
        bpl selohalf
        ora #$10
selohalf:
        ldy #$30
        jsr ultimaxWrite

        lda #$ff            ; check value
        tax
        tay                 ; timer
        ; check for value $ff
        bne checkEraseProgress

seloop_trampoline:
        bne seloop

; =============================================================================
;
; Return stuff, used by checkProgress
;
; =============================================================================
resetFlash:
        lda EAPI_SHADOW_BANK
        sta EASYFLASH_IO_BANK

        ; ldx #<$8000 - don't care
        lda #>$8000
        ldy #$f0
        jsr ultimaxWrite

        ; ldx #<$e000 - don't care
        lda #>$e000
        ldy #$f0
        jsr ultimaxWrite

        plp
        sec ; error
        bcs ret

retOk:
        plp
        clc
ret:
        ldy EAPI_WRITE_ADDR_HI
        ldx EAPI_WRITE_ADDR_LO
        lda EAPI_WRITE_VAL
        rts

; =============================================================================
;
; Check the progress. To do this, read the value at (YX) until it matches
; A or until a timer counter expires.
;
; If the timer expires, reset the flash chips and return an error indication.
; Otherwise return OK.
;
; As long as an operation is not complete or was cancelled because of an error,
; DQ can never be the expected value, as it contains a complement bit.
; As it seems that we can't read the toggle bit reliably on all hardware
; (read glitches?), we use this way to check the progress.
;
; =============================================================================
checkEraseProgress:
.cpLoop:
        jsr cmpByte
        beq .cpOK
        dex
        bne .cpLoop
        dey
        bne .cpLoop
        ; Time out and/or error
        clc
        bcc resetFlash
.cpOK:
        lda EAPI_TMP_VAL1
        clc
        adc #$80
        adc #$00
        sta EAPI_TMP_VAL1
        and #$87
        bne seloop_trampoline
        lda EAPI_SHADOW_BANK; todo: ?????
        sta EASYFLASH_IO_BANK
        clc
        bcc retOk

; =============================================================================
;
; EAPISetBank: User API: To be called with JSR jmpTable + 6 = $df86
;
; Set the bank. This will take effect immediately for cartridge read access
; and will be used for the next flash write or read command.
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
; EAPIGetBank: User API: To be called with JSR jmpTable + 9 = $df89
;
; Get the selected bank which has been set with EAPISetBank.
; Note that the current bank number can not be read back using the hardware
; register $de00 directly, this function uses a mirror of that register in RAM.
;
; This function can only be used after having called EAPIInit.
;
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
; EAPISetPtr: User API: To be called with JSR jmpTable + 12 = $df8c
;
; Set the pointer for EAPIReadFlashInc/EAPIWriteFlashInc.
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
; EAPISetLen: User API: To be called with JSR jmpTable + 15 = $df8f
;
; Set the number of bytes to be read with EAPIReadFlashInc.
;
; This function can only be used after having called EAPIInit.
;
; parameters:
;       XYA length, 24 bits (X = low, Y = med, A = high)
;
; return:
;       -
;
; changes:
;       -
;
; =============================================================================
EAPISetLen:
        stx EAPI_LENGTH_LO
        sty EAPI_LENGTH_MED
        sta EAPI_LENGTH_HI
        rts


; =============================================================================
;
; EAPIReadFlashInc: User API: To be called with JSR jmpTable + 18 = $df92
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
; This function can only be used after having called EAPIInit.
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

        ; call the read-routine
        jsr readByteForInc

        ; remember the result & x/y registers
        sta EAPI_WRITE_VAL
        stx EAPI_TMP_VAL1
        sty EAPI_TMP_VAL2

        ; make sure that the increment subroutine of the
        ; write routine jumps back to us, and call it
        lda #$00
        sta EAPI_WRITE_ADDR_HI
        beq rwInc_inc

readInc_Length:
        ; decrement length
        lda EAPI_LENGTH_LO
        bne readInc_nomed
        lda EAPI_LENGTH_MED
        bne readInc_nohi
        lda EAPI_LENGTH_HI
        beq readInc_eof
        dec EAPI_LENGTH_HI
readInc_nohi:
        dec EAPI_LENGTH_MED
readInc_nomed:
        dec EAPI_LENGTH_LO
        ;clc ; no EOF - already set by rwInc_noInc
        bcc rwInc_return

readInc_eof:
        sec ; EOF
        bcs rwInc_return


; =============================================================================
;
; EAPIWriteFlashInc: User API: To be called with JSR jmpTable + 21 = $df95
;
; Write a byte to the current pointer to EasyFlash flash memory.
; Increment the pointer according to the current bank wrap strategy.
; Pointer and wrap strategy have been set by a call to EAPISetPtr.
;
; In case of an error the position is not inc'ed.
;
;
; This function can only be used after having called EAPIInit.
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
        sta EAPI_WRITE_VAL
        stx EAPI_TMP_VAL1
        sty EAPI_TMP_VAL2

        ; load address to store to
        ldx EAPI_INC_ADDR_LO
        lda EAPI_INC_ADDR_HI
        cmp #$a0
        bcc writeInc_skip
        ora #$40 ; $a0 => $e0
writeInc_skip:
        tay
        lda EAPI_WRITE_VAL

        ; write to flash
        jsr jmpTable + 0
        bcs rwInc_return

        ; the increment code is used by both functions
rwInc_inc:
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
        ; no errors here, clear carry
        clc
        ; readInc: value has be set to zero, so jump back
        ; writeInc: value ist set by EAPIWriteFlash to the HI address (never zero)
        lda EAPI_WRITE_ADDR_HI
        beq readInc_Length
rwInc_return:
        ldy EAPI_TMP_VAL2
        ldx EAPI_TMP_VAL1
        lda EAPI_WRITE_VAL

EAPISetSlot:
EAPIGetSlot:
        rts

; =============================================================================
; We pad the file to the maximal driver size ($0300) to make sure nobody
; has the idea to use the memory behind EAPI in a cartridge. EasyProg
; replaces EAPI and would overwrite everything in this space.
!fill $0300 - (* - EAPICodeBase), $ff
