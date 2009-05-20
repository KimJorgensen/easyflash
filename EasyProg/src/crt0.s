;
; Startup code for cc65 (C64 version)
; modified
;
; This must be the *first* file on the linker command line
;

    .export        _exit
    .import        initlib, donelib, callirq
    .import        zerobss
    .import        callmain
    .import        RESTOR, BSOUT, CLRCH
    .import        __INTERRUPTOR_COUNT__
    .import        __HIRAM_START__, __HIRAM_SIZE__    ; Linker generated

    .importzp       sp, sreg, regsave
    .importzp       ptr1, ptr2, ptr3, ptr4
    .importzp       tmp1, tmp2, tmp3, tmp4
    .importzp       regbank

    zpspace = 26

IRQVec              := $0314

; ------------------------------------------------------------------------
; Place the startup code in a special segment.

.segment           "STARTUP"

; BASIC header with a SYS call

        .word   Head            ; Load address
Head:   .word   @Next
        .word   .version        ; Line number
        .byte   $9E,"2061"      ; SYS 2061
        .byte   $00             ; End of BASIC line
@Next:  .word   0               ; BASIC end marker

; ------------------------------------------------------------------------
; Actual code

        ldx #zpspace-1
L1:     lda sp,x
        sta zpsave,x    ; Save the zero page locations we need
        dex
        bpl L1

        ; Close open files
        jsr CLRCH

        ; Switch to second charset
        lda #14
        jsr BSOUT

        ; Clear the BSS data
        jsr zerobss

        tsx
        stx spsave      ; Save the system stack ptr

        ; Set argument stack ptr
        lda #<(__HIRAM_START__ + __HIRAM_SIZE__)
        sta sp
        lda #>(__HIRAM_START__ + __HIRAM_SIZE__)
        sta sp+1

; If we have IRQ functions, chain our stub into the IRQ vector
        lda #<__INTERRUPTOR_COUNT__
        beq NoIRQ1
        lda IRQVec
        ldx IRQVec+1
        sta IRQInd+1
        stx IRQInd+2
        lda #<IRQStub
        ldx #>IRQStub
        sei
        sta IRQVec
        stx IRQVec+1
        cli

NoIRQ1:
        ; Call module constructors
        jsr initlib

        ; Push arguments and call main
        jsr callmain

_exit:
        ; Back from main (This is also the _exit entry). Run module destructors
        jsr donelib

        ; Reset the IRQ vector if we chained it.
        lda #<__INTERRUPTOR_COUNT__
        beq NoIRQ2
        lda IRQInd+1
        ldx IRQInd+2
        sei
        sta IRQVec
        stx IRQVec+1
        cli

        ; Copy back the zero page stuff
NoIRQ2:
        ldx #zpspace-1
L2:
        lda zpsave,x
        sta sp,x
        dex
        bpl L2

; Restore system stuff

        ldx spsave
        txs             ; Restore stack pointer

; Reset changed vectors, back to basic
        jmp RESTOR

; ------------------------------------------------------------------------
; The IRQ vector jumps here, if condes routines are defined with type 2.

IRQStub:
        cld             ; Just to be sure
        jsr callirq     ; Call the functions
        jmp IRQInd      ; Jump to the saved IRQ vector

; ------------------------------------------------------------------------
.data

IRQInd:
        jmp $0000


; ------------------------------------------------------------------------
.segment "ZPSAVE"

zpsave:
        .res zpspace

; ------------------------------------------------------------------------
.bss

spsave:
        .res 1
