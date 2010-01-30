;
; hostasm.s - Some utility functions
;
; (c) 2010 Thomas 'skoe' Giesel
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

.export _XsvfLogScroll
_XsvfLogScroll:
        ldx #13     ; width - 1
logScrollLoop:
        lda $0400 + 10 * 40 + 24, x
        sta $0400 +  9 * 40 + 24, x

        lda $0400 + 11 * 40 + 24, x
        sta $0400 + 10 * 40 + 24, x

        lda $0400 + 12 * 40 + 24, x
        sta $0400 + 11 * 40 + 24, x

        lda $0400 + 13 * 40 + 24, x
        sta $0400 + 12 * 40 + 24, x

        lda $0400 + 14 * 40 + 24, x
        sta $0400 + 13 * 40 + 24, x

        lda #$20
        sta $0400 + 14 * 40 + 24, x

        dex
        bpl logScrollLoop
        rts
