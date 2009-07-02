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


; flashcode.s
;
; This file contains low level code for accessing the flash memory chips.
;
; This code switches the machine to Ultimax mode. Because of this the base
; address of the ROMH chip is $E000, not $A000 - even if the stuff you write
; is intended to run from $A000 later.
;
;       Interrupts will be disabled during execution
;
; On exit:
;       Interrupts enabled, Module ROM enabled

    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4
    .importzp       regbank

    .import         popax

; Set this to if you have easyflash-draft3 hardware or later
HW_DRAFT3 = 1

; base address of chip (2 bytes, LE)
zp_flashcode_base   = ptr1

; address (2 bytes, LE)
zp_flashcode_addr   = ptr2

; temp pointer (2 bytes)
zp_flashcode_555    = ptr3

; temp pointer (2 bytes)
zp_flashcode_2aa    = ptr4

; argument/return: value (1 byte)
zp_flashcode_val    = tmp1


; I/O address used to select the bank
EASYFLASH_IO_BANK    = $de00

.ifdef HW_DRAFT3

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

.else

EASYFLASH_IO_CONTROL = $de01

; Bit for memory control (1 = enabled)
EASYFLASH_IO_BIT_MEMCTRL = $20

; Bit for Expansion Port /GAME line (0 = low)
EASYFLASH_IO_BIT_GAME    = $40

; Bit for Expansion Port /EXROM line (0 = low)
EASYFLASH_IO_BIT_EXROM   = $80

; Bit for status LED (dummy in this version)
EASYFLASH_IO_BIT_LED     = $01

.endif

FLASH_ALG_ERROR_BIT      = $20

.segment "LOWCODE"

; =============================================================================
;
; Calculate the two magic addresses base + $0555 and base + $2AA
;
; read:
;       zp_flashcode_base ist bast
;
; write:
;       zp_flashcode_555 and zp_flashcode_2aa
;
; =============================================================================
flashCodeCalcMagicAddresses:
        ; prepare base + $555
        clc
        lda zp_flashcode_base
        adc #$55
        sta zp_flashcode_555
        lda zp_flashcode_base + 1
        adc #$05
        sta zp_flashcode_555 + 1

        ; prepare base + $2AA
        ; c is still clear
        lda zp_flashcode_base
        adc #$aa
        sta zp_flashcode_2aa
        lda zp_flashcode_base + 1
        adc #$02
        sta zp_flashcode_2aa + 1
        rts


; =============================================================================
;
; Disable interrupts and turn on Ultimax mode and LED.
;
; =============================================================================
flashCodeActivateUltimax:
        sei
        ; /GAME low, /EXROM high, LED on
.ifdef HW_DRAFT3
        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_LED
.else
        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_EXROM
.endif
        sta EASYFLASH_IO_CONTROL
        rts


; =============================================================================
;
; Turn off Ultimax mode (show 16k of the currently selected bank at $8000)
; and enable interrupts. Turn off the LED.
;
; modify: A
;
; =============================================================================
flashCodeDeactivateUltimax:
        ; /GAME low, /EXROM low, LED off
.ifdef HW_DRAFT3
        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_EXROM
.else
        lda #EASYFLASH_IO_BIT_MEMCTRL
.endif
        sta EASYFLASH_IO_CONTROL
        lda bank
        sta EASYFLASH_IO_BANK
        cli
        rts


; =============================================================================
;
; Write command cycles 1 and 2 to the flash chip.
;
; preconditions:
;       - flashCodeCalcMagicAddresses must have been called
;       - must be in Ultimax mode
;
; =============================================================================
flashCodeCommandCycles12:
        ; cycle 1: write $AA to $555
        lda #$aa
        ldy #0
        ; select bank 0
        sty EASYFLASH_IO_BANK
        sta (zp_flashcode_555),y
        ; cycle 2: write $55 to $2AA
        lda #$55
        sta (zp_flashcode_2aa),y
        rts


; =============================================================================
;
; Calculate the magic addresses, go to Ultimax mode, bank 0 and send command
; cycles 1 and 2.
;
; =============================================================================
flashCodePrepareWrite:
        jsr flashCodeCalcMagicAddresses
        jsr flashCodeActivateUltimax
        jmp flashCodeCommandCycles12


; =============================================================================
;
; Set the bank. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; void __fastcall__ flashCodeSetBank(uint8_t nBank);
;
; parameters:
;       bank in A (0..63)
;
; return:
;       -
;
; =============================================================================
.export _flashCodeSetBank
_flashCodeSetBank:
        sta bank
        sta EASYFLASH_IO_BANK
        rts


; =============================================================================
;
; Read Manufacturer ID and Device ID from the chip at the given address.
;
; unsigned __fastcall__ flashCodeReadIds(uint8_t* pBase);
;
; parameters:
;       base in AX (A = low), $8000 or $E000
;
; return:
;       result in AX (A = low = Device ID, X = high = Manufacturer ID)
;
; =============================================================================
.export _flashCodeReadIds
_flashCodeReadIds:
        sta zp_flashcode_base
        stx zp_flashcode_base + 1
        jsr flashCodePrepareWrite

        ; cycle 3: write $90 to $555
        ldy #0
        lda #$90
        sta (zp_flashcode_555),y

        ; offset 0: Manufacturer ID
        lda (zp_flashcode_base),y
        tax

        ; offset 1: Device ID
        iny
        lda (zp_flashcode_base),y
        pha

        ; reset flash chip: write $F0 to any address
        lda #$f0
        sta (zp_flashcode_base),y

        jsr flashCodeDeactivateUltimax

        ; Manufacturer still on X, get Device from stack into A
        pla
        rts


; =============================================================================
;
; Erase the sector at the given address.
;
; This is done in background by the chip, the caller should check the progress
; according to the flash spec.
;
; void __fastcall__ flashCodeSectorErase(uint8_t* pBase);
;
; parameters:
;       base in AX (A = low), $8000 or $E000
;
; return:
;       -
;
; =============================================================================
.export _flashCodeSectorErase
_flashCodeSectorErase:
        sta zp_flashcode_base
        stx zp_flashcode_base + 1
        jsr flashCodePrepareWrite

        ; cycle 3: write $80 to $555
        ldy #0
        lda #$80
        sta (zp_flashcode_555),y
        ; cycle 4: write $AA to $555
        lda #$aa
        sta (zp_flashcode_555),y
        ; cycle 5: write $55 to $2AA
        lda #$55
        sta (zp_flashcode_2aa),y

        ; now we have to activate the right bank and stay in Ultimax
        lda bank
        sta EASYFLASH_IO_BANK

        ; cycle 6: write $30 to base + SA
        lda #$30
        sta (zp_flashcode_base),y

        ; that's it
        jmp flashCodeDeactivateUltimax


; =============================================================================
;
; Write a byte to the given address.
;
; This is done in background by the chip, the caller should check the progress
; according to the flash spec.
;
; void __fastcall__ flashCodeWrite(uint8_t* pAddr, uint8_t nVal);
;
; parameters:
;       value in A
;       address on cc65-stack $8xxx/$9xxx or $Exxx/$Fxxx
;
; return:
;       -
;
; =============================================================================
.export _flashCodeWrite
_flashCodeWrite:
        ; remember value
        pha

        ; get and save address
        jsr popax
        sta zp_flashcode_addr
        stx zp_flashcode_addr + 1

        ; calculate base address, i.e. $8000 or $E000
        lda #0
        sta zp_flashcode_base
        txa
        and #$e0
        sta zp_flashcode_base + 1

        jsr flashCodePrepareWrite

        ; cycle 3: write $A0 to $555
        ldy #0
        lda #$a0
        sta (zp_flashcode_555),y

        ; now we have to activate the right bank
        lda bank
        sta EASYFLASH_IO_BANK

        ; cycle 4: write data
        pla
        sta (zp_flashcode_addr),y

        ; that's it
        jmp flashCodeDeactivateUltimax


; =============================================================================
;
; Write a byte to the given address.
;
; Check the program or erase progress of the flash chip at the given base
; address (normal base).
;
; Return 1 for success, 0 for error;
; uint8_t __fastcall__ flashCodeCheckProgress(uint8_t* pAddr);
;
; parameters:
;       base in AX (A = low), $8000 or $A000
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _flashCodeCheckProgress
.proc   _flashCodeCheckProgress
_flashCodeCheckProgress:
        cpx #$a0
        beq l_a000
        ; check progress of flash memory at $8000

        ; wait as long as the toggle bit toggles
l8_1:
        lda $8000
        cmp $8000
        bne l8_different
        ; read once more to catch the case status => data
        cmp $8000
        beq ret_ok
l8_different:
        ; check if the error bit is set
        and #FLASH_ALG_ERROR_BIT
        bne ret_err
        ; wait longer if not
        beq l8_1        ; always

l_a000:
        ; same code for $e000
        ; wait as long as the toggle bit toggles
la_1:
        lda $a000
        cmp $a000
        bne la_different
        ; read once more to catch the case status => data
        cmp $a000
        beq ret_ok
la_different:
        ; check if the error bit is set
        and #FLASH_ALG_ERROR_BIT
        bne ret_err
        ; wait longer if not
        beq la_1

ret_err:
        ldx #0
        txa
        rts
ret_ok:
        ldx #0
        lda #1
        rts
.endproc


; =============================================================================
; Data in same segment, must be visible in Ultimax mode
; =============================================================================

; Current bank
bank:
        .res 1

; EOF
