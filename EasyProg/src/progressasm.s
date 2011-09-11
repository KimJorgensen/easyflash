;
; EasyFlash - spritesasm.s - Sprites
;
; (c) 2011 Thomas 'skoe' Giesel
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

PROGRESS_SCREEN_ADDR    = $0400 + 17 * 40 + 6
PROGRESS_COLOR_ADDR     = $d800 + 17 * 40 + 6
PROGRESS_BANKS_PER_LINE = 32

.import _m_aBlockStates

.code

; =============================================================================
;
; Update the progress display area, values only.
;
; void progressUpdateDisplay(void);
;
;
; parameters:
;       -
;
; return:
;       -
;
; =============================================================================
.export _progressUpdateDisplay
_progressUpdateDisplay:
        lda #<_m_aBlockStates
        sta ptr1
        lda #>_m_aBlockStates
        sta ptr1 + 1

        lda #<PROGRESS_SCREEN_ADDR
        sta ptr2
        sta ptr3
        lda #>PROGRESS_SCREEN_ADDR
        sta ptr2 + 1

        lda #>PROGRESS_COLOR_ADDR
        sta ptr3 + 1

        ldx #3
line_loop:
        ldy #PROGRESS_BANKS_PER_LINE - 1
bank_loop:
        lda (ptr1), y
        sta (ptr2), y
        lda $0286       ; foreground color
        sta (ptr3), y
        dey
        bpl bank_loop

        clc
        lda ptr1
        adc #PROGRESS_BANKS_PER_LINE
        sta ptr1
        bcc :+
        inc ptr1 + 1
:
        clc
        lda ptr2
        adc #40
        sta ptr2
        sta ptr3
        bcc :+
        inc ptr2 + 1
:
        clc
        lda ptr2 + 1
        adc #>(PROGRESS_COLOR_ADDR - PROGRESS_SCREEN_ADDR)
        sta ptr3 + 1

        dex
        bpl line_loop
        rts
