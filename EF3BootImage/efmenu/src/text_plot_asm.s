;
; EasyFlash - text_plot_asm.s - Text Plotter
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

.include "c64.inc"

.include "memcfg.inc"

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4

; Data import
.import _text_plot_x
.import _text_plot_y

.import charset_tab_lo
.import charset_tab_hi

.export _text_plot_char

; usage of tmp space in this module
ptr1_char_addr          = ptr1
ptr2_pixel_addr         = ptr2
ptr3_tmp_addr           = ptr3
tmp1_pixel_col          = tmp1
tmp2_current_col        = tmp2
tmp3_mask               = tmp3


; =============================================================================
; Y coordinate => address of bitmap line
; *** 2 * 200 bytes ***
.rodata
y_pos_to_addr_lo:
.repeat 25, line
.repeat 8, n
        .byte <(P_GFX_BITMAP + n + line * 320)
.endrep
.endrep
y_pos_to_addr_hi:
.repeat 25, line
.repeat 8, n
        .byte >(P_GFX_BITMAP + n + line * 320)
.endrep
.endrep

; =============================================================================
; X coordinate => mask
.rodata
x_pos_to_mask:
        .byte $80, $40, $20, $10, $08, $04, $02, $01

; =============================================================================
;
; void __fastcall__ text_plot_char(char ch);
;
; Plot the character ch to the bitmap at _text_plot_x/_text_plot_y.
; No clipping here.
;
; in:
;       A = ch
;
; out:
;   -
;
.code
_text_plot_char:
        ; get address of character bitmap
        tay
        lda charset_tab_lo, y
        sta ptr1_char_addr
        lda charset_tab_hi, y
        sta ptr1_char_addr + 1

        ; get address of first pixel line in destination bitmap
        ldy _text_plot_y
        lda y_pos_to_addr_lo, y
        sta ptr2_pixel_addr
        lda y_pos_to_addr_hi, y
        sta ptr2_pixel_addr + 1

        ; add offset of X coordinate
        lda _text_plot_x
        and #255 - 7                    ; 8 pixels = 1 byte
        clc
        adc ptr2_pixel_addr
        sta ptr2_pixel_addr
        lda _text_plot_x + 1
        adc ptr2_pixel_addr + 1
        sta ptr2_pixel_addr + 1

        ; calculate bit mask for first pixel row
        lda _text_plot_x
        and #7
        tax
        lda x_pos_to_mask, x
        sta tmp3_mask

        ldy #0
        sty tmp2_current_col            ; save index of column
        lda (ptr1_char_addr), y         ; get pixels for column
@next_column:
        sta tmp1_pixel_col              ; save pixels of column

        ; restore start values for this line
        ldy ptr2_pixel_addr
        sty ptr3_tmp_addr
        ldy ptr2_pixel_addr + 1
        sty ptr3_tmp_addr + 1

        ; calc number of line with simple addr inc
        lda _text_plot_y                ; absolute Y
        eor #$ff
        and #$07                        ; 0 => 7, 1 => 6 etc.
        tax
        inx                             ; => number of lines w/ simple inc

        ldy #0                          ; relative Y, 0..7
.repeat 8, n
        ror tmp1_pixel_col              ; next bit (pixel) into C
        bcc :+                          ; no pixel => skip
        lda tmp3_mask
        ora (ptr3_tmp_addr), y          ; put pixel
        sta (ptr3_tmp_addr), y
:
        dex                             ; simple addr inc?
        bne :+                          ; no new 320-byte line
        lda ptr3_tmp_addr
        clc
        adc #<(320 - 8)
        sta ptr3_tmp_addr
        lda ptr3_tmp_addr + 1
        adc #>(320 - 8)
        sta ptr3_tmp_addr + 1
:
        iny
.endrep

        inc _text_plot_x
        bne :+
        inc _text_plot_x + 1
:
        lda _text_plot_x
        and #7
        bne @no_new_addr
        lda ptr2_pixel_addr             ; advance to next byte
        clc
        adc #8
        sta ptr2_pixel_addr
        bcc :+
        inc ptr2_pixel_addr + 1
:
@no_new_addr:
        lda tmp3_mask                   ; update mask for next row
        lsr a
        ror tmp3_mask

        inc tmp2_current_col            ; index of next column
        ldy tmp2_current_col
        lda (ptr1_char_addr), y         ; get pixels for column
        beq @end
        jmp @next_column
@end:
        rts
