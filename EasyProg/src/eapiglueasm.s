
.importzp       sp, sreg, regsave
.importzp       ptr1, ptr2, ptr3, ptr4
.importzp       tmp1, tmp2, tmp3, tmp4

.import         popax

.import _g_nSelectedSlot

; Entry points for EasyFlash driver (EAPI)
EAPIBase            = $c000         ; <= Use any address here
EAPIInit            = EAPIBase + 20
EAPIWriteFlash      = $df80 +  0
EAPIEraseSector     = $df80 +  3
EAPISetBank         = $df80 +  6
EAPIGetBank         = $df80 +  9
EAPISetPtr          = $df80 + 12
EAPISetLen          = $df80 + 15
EAPIReadFlashInc    = $df80 + 18
EAPIWriteFlashInc   = $df80 + 21
EAPISetSlot         = $df80 + 24
EAPIGetSlot         = $df80 + 27

EASYFLASH_SLOT    = $de01

EASYFLASH_CONTROL = $de02
EASYFLASH_KILL    = $04
EASYFLASH_16K     = $07

.segment "LOWCODE"

; =============================================================================
;
; Hide BASIC/Cartridge ROM and CLI.
;
; changes: Y
;
; =============================================================================
.export _efHideROM
_efHideROM:
        ldy #$36
        sty $01
        ldy #EASYFLASH_KILL
        sty EASYFLASH_CONTROL ; avoid the evil mode with cart ROM at $a000
        cli
        rts


; =============================================================================
;
; Show BASIC/Cartridge ROM.
;
; changes: Y
;
; =============================================================================
.export _efShowROM
_efShowROM:
        sei
        ldy #$37
        sty $01
        ldy #EASYFLASH_16K
        sty EASYFLASH_CONTROL
        rts


; =============================================================================
;
; Map cartridge ROM, read a byte from cartridge ROM, hide ROM again.
;
; parameters:
;       pointer in AX
; return:
;       value in A
;
; =============================================================================
.export _efPeekCartROM
_efPeekCartROM:
        sta ptr1
        stx ptr1 + 1
        lda _g_nSelectedSlot
        sta EASYFLASH_SLOT
        jsr _efShowROM
        ldy #0
        lda (ptr1), y
        jsr _efHideROM
        ldx #0
        rts


; =============================================================================
;
; Compare 256 bytes of flash contents and RAM contents. The bank must already
; be set up. The whole block must be located in one bank and in one flash
; chip.
;
; Return 0 for success, the bad flash memory address for error
; uint8_t* __fastcall__ efVerifyFlash(uint8_t* pFlash, uint8_t* pRAM);
;
; Do not call this from Ultimax mode, Use normal addresses (8000/a000)
;
; parameters:
;       RAM address in AX (A = low)
;       flash address on cc65-stack
;
; return:
;       result in AX (A = low), 0 = okay, address in flash = error
;
; =============================================================================
.export _efVerifyFlash
.proc   _efVerifyFlash
_efVerifyFlash:

        sta ptr1
        stx ptr1 + 1

        ; get and save address
        jsr popax
        sta ptr2
        stx ptr2 + 1

        sei
        ldy _g_nSelectedSlot
        sty EASYFLASH_SLOT
        ldy #$37
        sty $01
        ldy #EASYFLASH_16K
        sty EASYFLASH_CONTROL

        ldy #0
l1:
        lda (ptr2), y
        cmp (ptr1), y
        bne bad
        iny
        bne l1

        ; okay, return NULL
        tya
        tax
        jmp ret4
bad:
        ; return bad flash address
        ldx ptr2 + 1    ; high byte
        clc
        tya
        adc ptr2        ; low byte + bad offset
        bcc nohigh
        inx
nohigh:
ret4:
        ldy #$36
        sty $01
        ldy #EASYFLASH_KILL
        sty EASYFLASH_CONTROL
        cli

        rts

.endproc


; =============================================================================
;
; (refer to EasyAPI documentation)
; In case of an error, the error code is returned in *pDeviceId.
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

        jsr _efShowROM
        jsr EAPIInit
        sty tmp1
        jsr _efHideROM

        ldy #0
        sta (ptr2),y    ; Device ID
        txa
        sta (ptr1),y    ; Manufacturer ID

        bcc eiOK
        lda #0
        tax
        rts
eiOK:
        lda tmp1
        ldx #0
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
;       bank in AX (A = low)
;
; =============================================================================
.export _eapiGetBank
_eapiGetBank:
        jsr EAPIGetBank
        ldx #0
        rts

; =============================================================================
;
; Set the bank. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; void __fastcall__ eapiSetBank(uint8_t nBank);
;
; parameters:
;       bank in A
;
; return:
;       -
;
; =============================================================================
.export _eapiSetBank
_eapiSetBank:
        jmp EAPISetBank

; =============================================================================
;
; Get the selected slot.
;
; uint8_t __fastcall__ eapiGetSlot(void);
;
; parameters:
;       -
;
; return:
;       slot in AX (A = low)
;
; =============================================================================
.export _eapiGetSlot
_eapiGetSlot:
        jsr EAPIGetSlot
        ldx #0
        rts

; =============================================================================
;
; Set the slot. This will take effect immediately for read access and will be
; used for the next write and erase commands.
;
; void __fastcall__ eapiSetSlot(uint8_t nSlot);
;
; parameters:
;       slot in A
;
; return:
;       -
;
; =============================================================================
.export _eapiSetSlot
_eapiSetSlot:
        jmp EAPISetSlot

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
        jsr _efShowROM

        lda _g_nSelectedSlot
        sta EASYFLASH_SLOT

        ; x to y (high byte of address)
        txa
        tay

        jsr EAPIGetBank
        jsr EAPIEraseSector
        jsr _efHideROM

        lda #0
        tax
        bcs eseError
        lda #1
eseError:
        rts


; =============================================================================
;
; Write a byte to the given address.
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
        jsr _efShowROM

        ; remember value
        pha

        lda _g_nSelectedSlot
        sta EASYFLASH_SLOT

        ; get address
        jsr popax
        ; ax to xy
        pha
        txa
        tay
        pla
        tax

        pla

        jsr EAPIWriteFlash
        jsr _efHideROM
        lda #0
        tax
        bcs ewfError
        lda #1
ewfError:
        rts

; =============================================================================
;
; Write 256 bytes to the given address. The destination address must be
; aligned to 256 bytes.
;
; uint8_t __fastcall__ eapiGlueWriteBlock(uint8_t* pDst, uint8_t* pSrc);
;
; parameters:
;       source address in AX
;       destination address on cc65-stack $8xxx/$9xxx or $Exxx/$Fxxx
;
; return:
;       result in AX (A = low), 0x100 = okay, offset with error otherwise
;
; =============================================================================
.export _eapiGlueWriteBlock
_eapiGlueWriteBlock:
        sta wbNext + 1
        stx wbNext + 2

        ; get address
        jsr popax
        ; ax to xy
        pha
        txa
        tay
        pla
        tax

        lda _g_nSelectedSlot
        sta EASYFLASH_SLOT

wbNext:
        lda $1000, x        ; will be modified

        sty tmp1
        jsr _efShowROM
        ldy tmp1            ; todo: optimize!

        ; parameters for EAPIWriteFlash
        ;       A   value
        ;       XY  address (X = low), $8xxx/$9xxx or $Exxx/$Fxxx
        jsr EAPIWriteFlash

        sty tmp1
        jsr _efHideROM
        ldy tmp1            ; todo: optimize!

        bcs wbError

        inx
        bne wbNext

        ; return 0x100 => okay
        lda #0
        ldx #$01
        rts

wbError:
        ; return bad offset in AX
        txa
        ldx #0
        rts

; =============================================================================
;
; Include EAPI drivers
;
; =============================================================================
.segment    "RODATA"

.export _aEAPIDrivers
_aEAPIDrivers:

EAPICode1:
@CodeStart:
.incbin "obj/eapi-m29w160t-03", 2
.res $0300 - (* - @CodeStart), $ff

EAPICode2:
@CodeStart:
.incbin "obj/eapi-am29f040-13", 2
.res $0300 - (* - @CodeStart), $ff

EAPICode3:
@CodeStart:
.incbin "obj/eapi-mx29640b-01", 2
.res $0300 - (* - @CodeStart), $ff

EAPICodeEnd:
.byte 0
