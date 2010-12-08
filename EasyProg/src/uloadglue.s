
    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4

    .import         popax

    .import         loader_init
    .import         loader_exit
    .import         loader_open
    .import         loader_read
    .import         utilAskForNextCrunchedFile
    .import         utilGetCrunchedByteCancel

.bss
uloadEOFSeen:
    .res 1

.code
; =============================================================================
;
; Initialize uload and detect the drive type.
;
; uint8_t uloadInit(void);
;
; parameters:
;       -
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _uloadInit
_uloadInit:
        ;jsr loader_init
        ;jsr checkOpenReturn     ; this will reset uloadEOFSeen upon success
                                ; and create the return code in A
        ldy #1
        sty uloadEOFSeen        ; overwrite EOFSeen: always EOF after Init
        rts

checkOpenReturn:
        ldx #0
        stx uloadEOFSeen
        lda #1
        bcc :+
        txa
        inc uloadEOFSeen
        rts


; =============================================================================
;
; Read a byte.
;
; int uloadReadByte(void);
;
; parameters:
;       -
;
; return:
;       result in AX (A = low), -1 = EOF/Error, byte otherwise
;
; =============================================================================
.export _uloadReadByte
_uloadReadByte:
        lda uloadEOFSeen
        bne @retEOF
        jsr loader_read
        ldx #0
        bcc :+
        inc uloadEOFSeen
@retEOF:
        lda #$ff
        tax
:
        rts

; =============================================================================
;
; Exit the ULoad drive code.
;
; void uloadExit(void);
;
; parameters:
;       -
;
; return:
;       -
;
; =============================================================================
.export _uloadExit
_uloadExit:
        jmp loader_exit

; =============================================================================
;
; Open the file for reading.
;
; uint8_t __fastcall__ uloadOpenFile(const char* name);
;
; parameters:
;       pointer to name in AX (A = low)
;
; return:
;       result in AX (A = low), 1 = okay, 0 = error
;
; =============================================================================
.export _uloadOpenFile
_uloadOpenFile:
        ldy #1
        jsr loader_open
        jmp checkOpenReturn


; =============================================================================
;
; int __fastcall__ uloadRead(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from a file to "buffer".
; Returns the number of bytes actually read, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
.export _uloadRead
_uloadRead:
        eor     #$FF
        sta     ptr1
        txa
        eor     #$FF
        sta     ptr1 + 1        ; Save -size-1

        jsr     popax
        sta     ptr2
        stx     ptr2 + 1        ; Save buffer

; bytesread = 0;

        lda     #$00
        tay
        sta     ptr3
        sta     ptr3 + 1
        beq     @Read3          ; Branch always

@Loop:
        lda     uloadEOFSeen
        bne     @End            ; Did we see EOF before?

        jsr     loader_read     ; Read next char from file

        bcs     @EOF            ; EOF?

        sta     (ptr2),y        ; Save read byte

        inc     ptr2
        bne     @Read2
        inc     ptr2+1          ; ++buffer;

@Read2:
        inc     ptr3
        bne     @Read3
        inc     ptr3 + 1        ; ++bytesread;
@Read3:
        inc     ptr1
        bne     @Loop
        inc     ptr1 + 1
        bne     @Loop

@End:
        lda     ptr3
        ldx     ptr3 + 1        ; return bytesread;

        rts
@EOF:
        inc uloadEOFSeen
        bcs @End                ; always

; =============================================================================
;
; called from get_crunched_byte:
;
; The decruncher jsr:s to the get_crunched_byte address when it wants to
; read a crunched byte. This subroutine has to preserve x and y register
; and must not modify the state of the carry flag.
;
; =============================================================================
        .export _uloadGetCrunchedByte
_uloadGetCrunchedByte:
        php
ugcbCont:
        lda uloadEOFSeen
        bne @EOF2           ; Did we see EOF before?
        jsr loader_read
        bcs @EOF
        plp
        rts

@EOF:
        inc uloadEOFSeen
@EOF2:
        ; save X, Y
        txa
        pha
        tya
        pha

        jsr utilAskForNextCrunchedFile
        ; restore X, Y
        pla
        tay
        pla
        tax
        bcs @cancel
        bcc ugcbCont
@cancel:
        ; skip the whole call chain and return from _utilReadEasySplitFile
        jmp utilGetCrunchedByteCancel
