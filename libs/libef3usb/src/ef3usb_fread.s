

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa, popax


size_zp      = ptr1
xfer_size_zp = ptr2
p_buff_zp    = ptr3
m_size_hi    = tmp1

.include "ef3usb_macros.s"

; =============================================================================
;
; unsigned int __fastcall__ usb_fread(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from USB to "buffer".
; Returns the number of bytes actually read, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
.proc   _ef3usb_fread
.export _ef3usb_fread
_ef3usb_fread:
        sta size_zp
        stx size_zp + 1         ; Save size

        jsr popax
        sta p_buff_zp
        stx p_buff_zp + 1       ; Save buffer address

        ldx size_zp
        ldy size_zp + 1
        wait_usb_tx_ok          ; request bytes (from XY)
        stx USB_DATA
        wait_usb_tx_ok
        sty USB_DATA

        ; get number of bytes actually there
        ; todo: we should check if this is more than we asked for
        wait_usb_rx_ok
        ldx USB_DATA            ; low byte of transfer size
        stx xfer_size_zp
        wait_usb_rx_ok
        ldy USB_DATA            ; high byte of transfer size
        sty xfer_size_zp + 1

        bne @loadCont
        cpx #0                  ; check for EOF
        beq @end                ; 0 bytes == EOF
@loadCont:
        txa
        eor #$ff
        tax
        tya
        eor #$ff
        sta m_size_hi           ; calc -size - 1
        ldy #0
        jmp @incCounter         ; inc to get -size
@getBytes:
        ; xy contains number of bytes to be xfered (x = low byte)
        wait_usb_rx_ok
        lda USB_DATA
        sta (p_buff_zp), y
        iny
        bne @incCounter
        inc p_buff_zp + 1
@incCounter:
        inx
        bne @getBytes
        inc m_size_hi
        bne @getBytes
@end:
        lda xfer_size_zp
        ldx xfer_size_zp + 1            ; return number of bytes transfered
        rts
.endproc
