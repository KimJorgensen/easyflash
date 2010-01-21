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
; Check if the 256 bytes of RAM at $DF00 are okay.
;
; Return 1 for success, 0 for error
; uint8_t __fastcall__ tortureTestCheckRAM(void);
;
; parameters:
;       base in AX (A = low), $8000 or $A000
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _tortureTestCheckRAM
.proc   _tortureTestCheckRAM
_flashCodeCheckRAM:

;		sei
;		lda #EASYFLASH_ULTIMAX
;		sta EASYFLASH_CONTROL

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
        bne l6  ; x = 0

		lda #EASYFLASH_KILL
		sta EASYFLASH_CONTROL
		cli
        lda #1
        rts
ret_err:
		lda #EASYFLASH_KILL
		sta EASYFLASH_CONTROL
		cli
        lda #0
        tax
        rts
.endproc

.export _flashCodeRAMLoop
.proc   _flashCodeRAMLoop
_flashCodeRAMLoop:
		sei
		lda #0
		sta $d011
		lda #$55
da:
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		sta $df00
		jmp da
.endproc



.export _flashCodeTestRead
.proc   _flashCodeTestRead
_flashCodeTestRead:
        ; write 0..255
        ldx #0
l1:
        txa
        sta $df00, x
        dex
        bne l1

testRead:
		dec $d020
        ldx #0
        ; check 0..255
l2:
        txa
        cmp $df00, x
        bne ret_err
        dex
        bne l2
		beq testRead
ret_err:
		lda #EASYFLASH_KILL
		sta EASYFLASH_CONTROL
		cli
        lda #0
        tax
        rts
.endproc

.export _ultimaxWrite
.proc   _ultimaxWrite
_ultimaxWrite:
        sei

        lda #EASYFLASH_ULTIMAX
        sta EASYFLASH_CONTROL

        lda #0
        sta $d011
        lda #$55
        ldx #$aa
uw1:
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        sta $8000
        stx $8001
        nop
        jmp uw2     ; 8 cycles
uw2:
        jmp uw1
.endproc



.export _kernalRamTest
.proc   _kernalRamTest
_kernalRamTest:
    sei

    lda $e00a
    sta $0400 + 15 * 40 + 5
    lda #$55
    sta $0400 + 15 * 40 + 6
    lda #$0f
    sta $0400 + 15 * 40 + 7

krt:
    lda #$36
    sta $01

    lda $e00a
    sta $0400 + 16 * 40 + 5

    lda #$55
    sta $e00a

    lda #$35
    sta $01

    lda $e00a
    sta $0400 + 16 * 40 + 6

    lda #$0f
    sta $e00a
    lda $e00a
    sta $0400 + 16 * 40 + 7

    dec $d020
    jmp krt
.endproc
