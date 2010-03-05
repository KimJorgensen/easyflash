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

    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4
    .importzp       regbank

    .import         popax

.segment "LOWCODE"

; address of buffer
zpbuff   = ptr1

; address of EasyFlash address
zpaddr   = ptr2

; address of EasyFlash offset
zpoffs   = ptr3

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_KILL    = $04
EASYFLASH_ULTIMAX = $05
EASYFLASH_8K      = $06
EASYFLASH_16K     = $07

; =============================================================================
;
; =============================================================================
.export _kernalRamRead
_kernalRamRead:
    clc
    sei
    lda #$35
    sta $01
    lda #$55
    sta $e123
krr:
    lda $e123
    cmp #$55
    beq krr
    dec $d020
    bcc krr

.export _kernalRamWriteCompare
_kernalRamWriteCompare:
    clc
    sei
    lda #$35
    sta $01
rwc_start:
    lda #$55
    sta $e100
    cmp $e100
    bne rwc_err
    lda #$aa
    sta $e100
    cmp $e100
    bne rwc_err
    jmp rwc_start
rwc_err:
    dec $d020
    jmp rwc_start

