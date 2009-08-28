;
; EasyFlash - spritesasm.s - Sprites
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

    .importzp       ptr1, ptr2, ptr3, ptr4


NUM_LOGO_SPRITES = 5

; temporary storage
zp_tmp   = ptr1

.code

; =============================================================================
;
; Show the sprites in the upper right corner.
;
; void spritesShow(void);
;
; parameters:
;       -
;
; return:
;       -
;
; =============================================================================
.export _spritesShow
.proc   _spritesShow
_spritesShow:
        ; positions
        ldx #2 * NUM_LOGO_SPRITES - 1
sh1:
        lda spritePos, x
        sta $d000, x            ; sprite coords
        dex
        bpl sh1

        ldx #NUM_LOGO_SPRITES - 1
sh2:
        lda spriteCol, x
        sta $d027, x            ; sprite colors
        dex
        bpl sh2

        ; sprite pointers are calc'd at runtime, because of the linker...
        ; we need spriteBitmapsStart / 64
        lda spriteBitmapsStart
        sta zp_tmp
        lda spriteBitmapsStart + 1
        sta zp_tmp + 1
        ; shift right 6 times
        ldx #6
sh3:
        lsr zp_tmp + 1
        ror zp_tmp
        dex
        bne sh3

        ldx #$29
        ldy #0
sh4:
        txa
        sta $07f8, y       ; sprite pointers
        inx
        iny
        cpy #NUM_LOGO_SPRITES
        bne sh4

        ldy #$ff
        sty $d010               ; sprite X MSB on
        iny
        sty $d017               ; sprite expand Y off
        sty $d01d               ; sprite expand X off
        sty $d01c               ; sprite MCM off

        lda #%00011111
        sta $d015               ; sprite display enable
        rts

spritePos:
    .byte 0 * 24, 56
    .byte 1 * 24, 56
    .byte 2 * 24, 56
    .byte 3 * 24, 56
    .byte     37, 56

spriteCol:
    .byte 0, 0, 0, 0, 8

.endproc


; =============================================================================
; =============================================================================
.data
.export _pSprites
_pSprites:
    .word spriteBitmapsStart


; =============================================================================
; Put the sprites into their own segment, this is in a quite low memory
; area so it's in the VIC bank. And it's aligned.
; =============================================================================
.segment "SPRITES"
spriteBitmapsStart:
.incbin "obj/sprites.bin"

