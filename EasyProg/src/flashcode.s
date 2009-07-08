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

.segment "LOWCODE"

; =============================================================================
;
; Disable interrupts and turn on Ultimax mode and LED.
;
; =============================================================================
flashCodeActivateUltimax:
        sei
        ; /GAME low, /EXROM high, LED on
        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_LED
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
        lda #EASYFLASH_IO_BIT_MEMCTRL | EASYFLASH_IO_BIT_GAME | EASYFLASH_IO_BIT_EXROM
        sta EASYFLASH_IO_CONTROL
        lda bank
        sta EASYFLASH_IO_BANK
        cli
        rts

; =============================================================================
;
; Calculate the magic addresses, go to Ultimax mode, bank 0 and send command
; cycles 1 and 2. Do this for the low flash chip which is visible at $8000.
;
; =============================================================================
flashCodePrepareWriteLow:
        ; select bank 0
        lda #0
        sta EASYFLASH_IO_BANK

        jsr flashCodeActivateUltimax

        ; cycle 1: write $AA to $555
        lda #$aa
        sta $8555
        ; cycle 2: write $55 to $2AA
        lda #$55
        sta $82AA
        rts

; =============================================================================
;
; Calculate the magic addresses, go to Ultimax mode, bank 0 and send command
; cycles 1 and 2. Do this for the low flash chip which is visible at $E000
; in Ultimax mode.
;
; =============================================================================
flashCodePrepareWriteHigh:
        ; select bank 0
        lda #0
        sta EASYFLASH_IO_BANK

        jsr flashCodeActivateUltimax

        ; cycle 1: write $AA to $555
        lda #$aa
        sta $E555
        ; cycle 2: write $55 to $2AA
        lda #$55
        sta $E2AA
        rts

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
.proc   _flashCodeReadIds
_flashCodeReadIds:

        ; address lower than $E000?
        cpx #$e0
        bcc low

        jsr flashCodePrepareWriteHigh

        ; cycle 3: write $90 to $555
        lda #$90
        sta $e555

        ; offset 0: Manufacturer ID
        lda $e000
        tax

        ; offset 1: Device ID
        lda $e001
        tay

        ; reset flash chip: write $F0 to any address
        lda #$f0
        sta $e000

        jsr flashCodeDeactivateUltimax

        ; Manufacturer still in X, move Device into A
        tya
        rts

low:
        jsr flashCodePrepareWriteLow

        ; cycle 3: write $90 to $555
        lda #$90
        sta $8555

        ; offset 0: Manufacturer ID
        lda $8000
        tax

        ; offset 1: Device ID
        lda $8001
        tay

        ; reset flash chip: write $F0 to any address
        lda #$f0
        sta $8000

        jsr flashCodeDeactivateUltimax

        ; Manufacturer still in X, move Device into A
        tya
        rts
.endproc

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
.proc   _flashCodeSectorErase
_flashCodeSectorErase:
        sta zp_flashcode_base
        stx zp_flashcode_base + 1

        ; address lower than $E000?
        cpx #$e0
        bcc low

        jsr flashCodePrepareWriteHigh

        ; cycle 3: write $80 to $555
        lda #$80
        sta $e555
        ; cycle 4: write $AA to $555
        lda #$aa
        sta $e555
        ; cycle 5: write $55 to $2AA
        lda #$55
        sta $e2aa

        jmp common

low:
        jsr flashCodePrepareWriteLow

        ; cycle 3: write $80 to $555
        lda #$80
        sta $8555
        ; cycle 4: write $AA to $555
        lda #$aa
        sta $8555
        ; cycle 5: write $55 to $2AA
        lda #$55
        sta $82aa

common:
        ; activate the right bank
        lda bank
        sta EASYFLASH_IO_BANK

        ; cycle 6: write $30 to base + SA
        lda #$30
        sta (zp_flashcode_base),y

        ; that's it
        jmp flashCodeDeactivateUltimax
.endproc

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
.proc   _flashCodeWrite
_flashCodeWrite:
        ; remember value
        pha

        ; get and save address
        jsr popax
        sta zp_flashcode_addr
        stx zp_flashcode_addr + 1

        ; address lower than $E000?
        cpx #$e0
        bcc writeLow

        jsr flashCodePrepareWriteHigh

        ; cycle 3: write $A0 to $555
        lda #$a0
        sta $e555

        jmp write_common

writeLow:
        jsr flashCodePrepareWriteLow

        ; cycle 3: write $A0 to $555
        lda #$a0
        sta $8555

write_common:
        ; now we have to activate the right bank
        lda bank
        sta EASYFLASH_IO_BANK

        ; cycle 4: write data
        pla
        ldy #0
        sta (zp_flashcode_addr),y

        ; that's it
        jmp flashCodeDeactivateUltimax
.endproc

; =============================================================================
;
; Check the program or erase progress of the flash chip at the given base
; address (normal base).
;
; !!! Do not call this from Ultimax mode, Use normal addresses (8000/a000) !!!
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
.endproc
ret_err:
        ldx #0
        txa
        rts
ret_ok:
        ldx #0
        lda #1
        rts

; =============================================================================
;
; Check if the 256 bytes of RAM at $DF00 are okay.
;
; Return 1 for success, 0 for error
; uint8_t __fastcall__ flashCodeCheckRAM(void);
;
; parameters:
;       base in AX (A = low), $8000 or $A000
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _flashCodeCheckRAM
.proc   _flashCodeCheckRAM
_flashCodeCheckRAM:
        ; write 0..255
        ldx #0
l1:
        txa
        sta $df00, x
        dex
        bne l1
        ; check 0..255
l2:
        txa
        cmp $df00, x
        bne ret_err
        dex
        bne l2

        ; write $55
        lda #$55
l3:
        sta $df00, x
        dex
        bne l3
        ; check $55
l4:
        cmp $df00, x
        bne ret_err
        dex
        bne l4

        ; write $AA
        lda #$AA
l5:
        sta $df00, x
        dex
        bne l5
        ; check $AA
l6:
        cmp $df00, x
        bne ret_err
        dex
        bne l6
        beq ret_ok
.endproc

; =============================================================================
; Data in same segment, must be visible in Ultimax mode
; =============================================================================

; Current bank
bank:
        .res 1

; EOF
