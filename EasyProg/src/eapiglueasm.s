
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popax

; Entry points for EasyFlash driver (EAPI)
EAPIBase            = $c000         ; <= Use any address here
EAPIInit            = EAPIBase + 4
EAPIWriteFlash      = $dfe0 + 0
EAPIEraseSector     = $dfe0 + 3
EAPISetBank         = $dfe0 + 6
EAPIGetBank         = $dfe0 + 9
EAPINumBanks        = $dfd8         ; 2 bytes lo/hi

; =============================================================================
;
; Read Manufacturer ID and Device ID from the flash chip(s)
; and check if this chip is supported by this driver.
; Prepare our private RAM for the other functions of the driver.
; When this function returns, EasyFlash will be configured to bank in the ROM
; area at $8000..$bfff.
;
; This function calls SEI/CLI.
;
; uint16_t __fastcall__ eapiInit(uint8_t* pManufacturerId, uint8_t* pDeviceId)
;
; parameters:
;       pDeviceId in AX
;       pManufacturerId on cc65-stack
; return:
;       number of banks in AX (A = low),
;                       0 = error, chipset not found or not supported
;
; =============================================================================
.export _eapiInit
_eapiInit:
        sta ptr2
        stx ptr2 + 1    ; pDeviceId
        jsr popax
        sta ptr1
        stx ptr1 + 1    ; pManufacturerId

        jsr EAPIInit

        ldy #0
        sta (ptr2),y    ; Device ID
        txa
        sta (ptr1),y    ; Manufacturer ID

        bcc eiOK
        lda #0
        tax
        rts
eiOK:
        lda EAPINumBanks
        ldx EAPINumBanks + 1
        rts


; =============================================================================
;
; Get the selected bank.
;
; uint8_t __fastcall__ eapiGetBank(void);
;
; parameters:
;       -
;
; return:
;       bank in AX (A = low, 0..63)
;
; =============================================================================
.export _eapiGetBank
_eapiGetBank:
        jmp EAPIGetBank ; XY registers are 16 bit bank
        txa
        pha
        tya
        tax
        pla
        rts

; =============================================================================
;
; Set the bank. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; void __fastcall__ eapiSetBank(uint8_t nBank);
;
; parameters:
;       bank in A (0..63)
;
; return:
;       -
;
; =============================================================================
.export _eapiSetBank
_eapiSetBank:
        tax
        ldy #0      ; XY registers are 16 bit bank
        jmp EAPISetBank

; =============================================================================
;
; Erase the sector at the given address.
;
; uint8_t __fastcall__ eapiSectorErase(uint8_t* pBase);
;
; parameters:
;       base in AX (A = low), $8000 or $E000
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _eapiSectorErase
_eapiSectorErase:
        pha ; AX => XY
        txa
        tay
        pla
        tax
        jsr EAPIEraseSector
        lda #0
        tax
        bcc eseNoError
        lda #1
eseNoError:
        rts


; =============================================================================
;
; Write a byte to the given address.
;
; This is done in background by the chip, the caller should check the progress
; according to the flash spec.
;
; uint8_t __fastcall__ eapiWriteFlash(uint8_t* pAddr, uint8_t nVal);
;
; parameters:
;       value in A
;       address on cc65-stack $8xxx/$9xxx or $Exxx/$Fxxx
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _eapiWriteFlash
_eapiWriteFlash:
        ; remember value
        pha

        ; get address
        jsr popax
        pha ; AX => XY
        txa
        tay
        pla
        tax

        pla

        jsr EAPIWriteFlash
        lda #0
        tax
        bcc ewfNoError
        lda #1
ewfNoError:
        rts

