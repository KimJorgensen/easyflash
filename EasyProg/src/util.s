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
