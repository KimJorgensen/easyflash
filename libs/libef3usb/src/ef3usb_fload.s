

.importzp   ptr1, ptr2, ptr3, ptr4
.importzp   tmp1, tmp2, tmp3, tmp4
.import     popa, popax


size_zp      = ptr1
xfer_size_zp = ptr2
p_buff_zp    = ptr3
start_addr   = ptr4
m_size_hi    = tmp1

.include "ef3usb_macros.s"

; =============================================================================
;
; unsigned void* ef3usb_fload(void);
;
; Load a file from USB to its start address (taken from the first two bytes).
; Return its start address. ptr1 contains the size on return.
;
; =============================================================================
.proc   _ef3usb_fload
.export _ef3usb_fload
_ef3usb_fload:
;        sta size_zp
;        stx size_zp + 1         ; Save size

;        jsr popax
;        sta p_buff_zp
;        stx p_buff_zp + 1       ; Save buffer address

;       ldx size_zp
;        ldy size_zp + 1
        lda #$ff                ; request 64k data
        wait_usb_tx_ok          ; request bytes (from XY)
        sta USB_DATA
        wait_usb_tx_ok
        sta USB_DATA

        ; get number of bytes actually there
        wait_usb_rx_ok
        ldx USB_DATA            ; low byte of transfer size
        stx xfer_size_zp
        stx size_zp
        wait_usb_rx_ok
        ldy USB_DATA            ; high byte of transfer size
        sty xfer_size_zp + 1
        sty size_zp + 1

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

        txa
        clc
        adc #3                  ; calc -size, add 2 more bytes (start addr)
        tax
        lda m_size_hi
        adc #0
        sta m_size_hi
        beq @end                ; file too short?

        wait_usb_rx_ok          ; read start address
        lda USB_DATA
        sta p_buff_zp
        sta start_addr
        wait_usb_rx_ok
        lda USB_DATA
        sta p_buff_zp + 1
        sta start_addr + 1

        ldy #0
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
        lda start_addr
        ldx start_addr + 1
        rts
.endproc
