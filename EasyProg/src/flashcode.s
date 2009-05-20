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
; This file contains relocatable low level code for accessing the flash memory
; chips.
;
; The main program moves this code to a RAM area below 0x1000, because this
; code switches the machine to Ultimax mode. This is the reason the base address
; of the ROMH chip is $E000, not $A000 - even if the stuff you write is intended
; to run from $A000 later.
;
; This is a single function. To say what you want, use an job code. It can be
; called from Assembly or from C with prototype void flashCodeExec(void).
; Job code, parameters and return values are transferred in zero page
; addresses. The C calling conventions are not used to make this code more
; independent from cc65. The CPU registers are not preserved. The arguments you
; write to the zeropage addresses are preserved.
;
; NOTE: Banking not implemented yet. All operations work on the first bank.
;
; On entry:
;
;               2:  Sector Erase
;
;               3:  Write - currently a dummy which writes 0x22 to 0x8000
;
;               4:  Read
;                   ZP_FLASHCODE_ADDR contains address to be read in current
;                   page (todo: paging not implemented yet, always page 0).
;                   Note that the chip base address (i.e. $8000 or $E000) must
;                   be added already.
;                   Value returned in ZP_FLASHCODE_VAL
;
;       Interrupts will be disabled during execution
;
; On exit:
;       Interrupts enabled, Module ROM disabled
;       Return values: Refer to job code descriptions

    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4
    .importzp       regbank


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


; I/O address used to select the bank, /GAME and /EXROM states
EASYFLASH_IO = $de00

; Bit for Expansion Port /GAME line (inverted: 1 = low)
EASYFLASH_IO_BIT_GAME = $40

; Bit for Expansion Port /EXROM line (inverted: 1 = low)
EASYFLASH_IO_BIT_EXROM = $80

; Job codes
EASYFLASH_JOB_READ_MANUFACTURER_ID  = 0
EASYFLASH_JOB_READ_DEVICE_ID        = 1
EASYFLASH_JOB_SECTOR_ERASE          = 2
EASYFLASH_JOB_WRITE                 = 3
EASYFLASH_JOB_READ                  = 4

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
; Disable interrupts and turn on Ultimax mode.
;
; =============================================================================
flashCodeActivateUltimax:
        sei
        ; switch to Ultimax mode and select ROM bank 0
        ; set /GAME low, /EXROM high => Ultimax
        lda #EASYFLASH_IO_BIT_EXROM
        sta EASYFLASH_IO
        rts


; =============================================================================
;
; Turn off Ultimax mode (show 16k at $8000) and enable interrupts.
;
; modify: A
;
; =============================================================================
flashCodeDeactivateUltimax:
        ; set /GAME low, /EXROM low => enable cartridge ROM
        lda #0
        sta EASYFLASH_IO
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
        sta (zp_flashcode_555),y
        ; cycle 2: write $55 to $2AA
        lda #$55
        sta (zp_flashcode_2aa),y
        rts


; =============================================================================
;
; Calculate the magic addresses, go to Ultimax mode and send command cycles
; 1 and 2.
;
; =============================================================================
flashCodePrepareWrite:
        jsr flashCodeCalcMagicAddresses
        jsr flashCodeActivateUltimax
        jmp flashCodeCommandCycles12


; =============================================================================
;
; Read Manufacturer ID and Device ID from the chip at the given address.
;
; unsigned __fastcall__ flashCodeReadIds(void* base);
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
; This is done in background by the chip, Use Jobcode "Read" from any address
; to check the progress: When you read $FF there, the erasure has been
; completed.
;
; void __fastcall__ flashCodeSectorErase(void* base);
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
        ; cycle 6: write $30 to base + SA
        lda #$30
        sta (zp_flashcode_base),y

        ; that's it
        jmp flashCodeDeactivateUltimax





.if 0 = 1

        ; ======== Job: Read from ZP_FLASHCODE_ADDR to ZP_FLASHCODE_VAL ========
        ldy #0
        lda (ZP_FLASHCODE_ADDR), y
        sta ZP_FLASHCODE_VAL
        clc
        bcc exit

NotJobRead:


checkJobWrite:
        cpx #EASYFLASH_JOB_WRITE
        bne exit

        ; ======== Job: Write ========
        ; cycle 3: write $A0 to $555
        lda #$A0
        sta (ZP_FLASHCODE_555),y
        ; cycle 4: write data
        lda #$22
        sta (ZP_FLASHCODE_BASE),y

exit:

; =============================================================================
; This label marks the end of the low level functions
; =============================================================================
        .export _flashCodeEnd
_flashCodeEnd:

.endif
