
; ------------------------------------------------------------------------
;
; load file
; args: start track, start sector
; returns: $00 for EOF, $ff for error, $01-$fe for each data block
load:
        ldx prev_file_track
        lda prev_file_sect
        jsr set_ts

loadchain:
@sendsector:
        jsr drv_readsector
        bcc :+
        lda #$ff                ; send read error
        jmp error
:
        ldx #254                ; send 254 bytes (full sector)
        lda drivebuffer         ; last sector?
        bne :+
        ldx drivebuffer + 1     ; send number of bytes in sector (1-254)
        dex
:
        stx @buflen
        txa
        jsr drv_send           ; send byte count

        ldx #0                  ; send data
@send:
        lda drivebuffer + 2,x
        jsr drv_send
        inx
@buflen = * + 1
        cpx #$ff
        bne @send

        jsr next_ts
        bcc @sendsector
@done:
        lda #0
        jmp senddone


drv_start:
        ; set the stack pointer (from x) to be restored upon exit
        tsx
        stx stack

drv_main:
        cli                     ; allow IRQs when waiting
        jsr drv_recv            ; get command byte, exit if ATN goes low

        cmp #1                  ; load a file
        beq load

        lda #$ff                ; unknown command
senddone:
error:
        jsr drv_send
        jmp drv_main

; next t/s in chain
next_ts:
        sec
        ldx drivebuffer
        beq ts_ret
        lda drivebuffer + 1
        clc
set_ts:
        stx track
        sta sector
ts_ret:
        rts
