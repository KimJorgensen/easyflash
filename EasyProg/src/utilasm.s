;
; EasyFlash - util.s - Some utility functions
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
;

.import         BASIN
.importzp       ptr1, ptr2, ptr3, tmp1
.import         popax, popa

.import         init_decruncher
.import         get_decrunched_byte
.import         _utilStr
.import         _utilAskForNextFile

.export buffer_start_hi: absolute
.export buffer_len_hi: absolute
buffer_start_hi   = $68             ; see buffer.h
buffer_len_hi     = 16              ; see EASY_SPLIT_MAX_EXO_OFFSET and buffer.h

; Kernal I/O Status Word ST
ST                = $90

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_KILL    = $04
EASYFLASH_ULTIMAX = $05
EASYFLASH_8K      = $06
EASYFLASH_16K     = $07

.segment "LOWCODE"


; =============================================================================
;
; Prepare the cartridge for being started and reset.
;
; =============================================================================
.export _utilResetStartCartridge
_utilResetStartCartridge:
        lda #EASYFLASH_LED | EASYFLASH_ULTIMAX
        sta EASYFLASH_CONTROL
        lda #0
        sta EASYFLASH_BANK
        jmp ($fffc)


; =============================================================================
;
; Disable the cartridge and reset.
;
; =============================================================================
.export _utilResetKillCartridge
_utilResetKillCartridge:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        jmp ($fffc)


; =============================================================================
;
; Include fallback EAPI driver.
;
; =============================================================================
.segment    "RODATA"
.export _pFallbackDriverStart
_pFallbackDriverStart:
        .word fallbackDriverStart

.export _pFallbackDriverEnd
_pFallbackDriverEnd:
        .word fallbackDriverEnd

fallbackDriverStart = * + 2
.incbin "eapi-am29f040-02"
fallbackDriverEnd:

; =============================================================================
; hex digits
; =============================================================================
.rodata
hexDigits:
        .byte "0123456789ABCDEF"

; =============================================================================
; Two's complement of uncompressed bytes remaining - 1 to be read from exomizer
; =============================================================================
.data
.export _nUtilExoBytesRemaining
_nUtilExoBytesRemaining:
        .res 4

.code

; =============================================================================
;
; Like cbm_read, but without calling CHKIN/CLRCH. The caller must have
; redirected the input already.
;
; int __fastcall__ utilReadNormalFile(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from a file to "buffer".
; Returns the number of actually read bytes, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
.export _utilReadNormalFile
_utilReadNormalFile:
        eor     #$FF
        sta     ptr1
        txa
        eor     #$FF
        sta     ptr1 + 1        ; Save -size-1

        jsr     popax
        sta     ptr2
        stx     ptr2 + 1        ; Save buffer

; bytesread = 0;

        lda     #$00
        sta     ptr3
        sta     ptr3 + 1
        beq     utilRead3       ; Branch always

; Loop

utilRead1:
        lda     ST              ; Status ok?
        bne     utilRead4

        jsr     BASIN           ; Read next char from file
        sta     tmp1            ; Save it for later

        lda     ST
        and     #$BF
        bne     utilRead4

        lda     tmp1
        ldy     #0
        sta     (ptr2),y        ; Save read byte

        inc     ptr2
        bne     utilRead2
        inc     ptr2+1          ; ++buffer;

utilRead2:
        inc     ptr3
        bne     utilRead3
        inc     ptr3 + 1        ; ++bytesread;
utilRead3:
        inc     ptr1
        bne     utilRead1
        inc     ptr1 + 1
        bne     utilRead1

utilRead4:
        lda     ptr3
        ldx     ptr3 + 1        ; return bytesread;

        rts


; =============================================================================
;
; The decruncher jsr:s to the get_crunched_byte address when it wants to
; read a crunched byte. This subroutine has to preserve x and y register
; and must not modify the state of the carry flag.
;
; =============================================================================

        .export get_crunched_byte
get_crunched_byte:
        ; save X, Y, C
        txa
        pha
        tya
        pha
        php

        lda ST          ; Status ok?
        bne gcbErr

get_crunched_byte2:
        jsr BASIN
        sta tmp1

        lda ST

        ; restore X, Y, C
        plp
        pla
        tay
        pla
        tax

        ; get result
        lda tmp1
        rts

gcbErr:

        ; backup cc65 ZP area
        ldx #$1a        ; see ld.conf
gbcE1:
        lda $02, x      ; see ld.conf
        sta $7900, x    ; BUFFER_ZP_BACKUP_ADDR
        dex
        bpl gbcE1

        jsr _utilAskForNextFile

        ; restore cc65 ZP area
        ldx #$1a        ; see ld.conf
gbcE2:
        lda $7900, x    ; BUFFER_ZP_BACKUP_ADDR
        sta $02, x      ; see ld.conf
        dex
        bpl gbcE2

        jmp get_crunched_byte2


; =============================================================================
;
; See exomizer documentation
;
; void utilInitDecruncher(void);
;
; =============================================================================

.export _utilInitDecruncher
_utilInitDecruncher:
        jmp init_decruncher


; =============================================================================
;
; Like cbm_read, but without calling CHKIN/CLRCH. The caller must have
; redirected the input already.
;
; int __fastcall__ utilReadEasySplitFile(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from a file to "buffer".
; Returns the number of actually read bytes, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
.export _utilReadEasySplitFile
_utilReadEasySplitFile:
        eor     #$FF
        sta     ptr1
        txa
        eor     #$FF
        sta     ptr1 + 1        ; Save -size-1

        jsr     popax
        sta     ptr2
        stx     ptr2 + 1        ; Save buffer

; bytesread = 0;

        lda     #$00
        sta     ptr3
        sta     ptr3 + 1
        beq     urs3            ; Branch always

; Loop

urs1:
        ; increment
        inc _nUtilExoBytesRemaining
        bne ursNoEOF
        inc _nUtilExoBytesRemaining + 1
        bne ursNoEOF
        inc _nUtilExoBytesRemaining + 2
        bne ursNoEOF
        inc _nUtilExoBytesRemaining + 3
        beq ursEnd

ursNoEOF:
        ; don't forget: this may call the disk change dialoge
        ; so before calling utilAskNextFile we must save the ptr1..ptr3
        jsr get_decrunched_byte

        ldy     #0
        sta     (ptr2),y        ; Save read byte

        inc     ptr2
        bne     urs2
        inc     ptr2 + 1        ; ++buffer;
urs2:
        inc     ptr3
        bne     urs3
        inc     ptr3 + 1        ; ++bytesread;

urs3:
        ; increment bytes to read (negative), end if 0 is reached
        inc     ptr1
        bne     urs1
        inc     ptr1 + 1
        bne     urs1

ursEnd:
        lda     ptr3
        ldx     ptr3 + 1        ; return bytesread;

        rts

; =============================================================================
;
; Append a single digit hex number to the string utilStr.
;
; void __fastcall__ utilAppendHex1(uint8_t n);
;
; parameters:
;       value n in A
;       address on cc65-stack
;
; return:
;       -
;
; =============================================================================
.export _utilAppendHex1
_utilAppendHex1:
        pha             ; remember n

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla
        pha

        ldy #0
utilAppendHex1_:
        ; get low nibble
        pla
        and #$0f
        tax
        lda hexDigits, x
        sta (ptr1), y

        ; 0-termination
        lda #0
        iny
        sta (ptr1), y

        rts


; =============================================================================
;
; Append a two digit hex number to the string utilStr.
;
; void __fastcall__ utilAppendHex2(uint8_t n);
;
; parameters:
;       value n in A
;
; return:
;       -
;
; =============================================================================
.export _utilAppendHex2
_utilAppendHex2:
        pha             ; remember n

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla

        ; get high nibble
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda hexDigits, x
        ldy #0
        sta (ptr1), y

        iny
        bne utilAppendHex1_ ; always

; =============================================================================
;
; Append a character to the string utilStr.
;
; void __fastcall__ utilAppendChar(char c);
;
; parameters:
;       character c in A
;
; return:
;       -
;
; =============================================================================
.export _utilAppendChar
_utilAppendChar:
        pha             ; remember c

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1

        ldy #0
        pla
        sta (ptr1), y

        ; 0-termination
        tya
        iny
        sta (ptr1), y

        rts

; =============================================================================
;
; Return the address of end of utilStr.
;
; parameters:
;       -
;
; return:
;       address of 0-termination of string in AX
;
; changes:
;       Y, C
;
; =============================================================================
;.export _utilGetStringEnd
_utilGetStringEnd:
        lda #<_utilStr
        ldx #>_utilStr
        sta ptr1
        stx ptr1 + 1

        ldy #0
gseNext:
        lda (ptr1), y
        beq gseEnd

        iny
        bne gseNoHi
        inc ptr1 + 1
        inx
gseNoHi:
        bne gseNext         ; always (as long as the string doesn't wrap to ZP)

gseEnd:
        clc
        tya                 ; update low-byte
        adc ptr1
        bcc gseEndNoHi
        inx
gseEndNoHi:
        rts
