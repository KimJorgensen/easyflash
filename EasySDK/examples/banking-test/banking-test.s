
; EasyFlashSDK sample code
; see README for a description details

* = $0000

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

; =============================================================================
; 00:0:0000 (LOROM, bank 0)
bankStart_00_0:
    ; This code resides on LOROM, it becomes visible at $8000
    !pseudopc $8000 {

        ; === the main application entry point ===
        ; copy the main code to $C000 (or whereever)
        ; normally you can put some exomizer compressed stuff here
        ldx #0
lp1:
        lda main,x
        sta $c000,x
        dex
        bne lp1
        jmp $c000

main:
        !pseudopc $C000 {
            ; Switch to bank 1, get a byte from LOROM and HIROM
            lda #1
            sta EASYFLASH_BANK
            lda $8000
            ldx $a000
            ; and put them to the screen, we should see "A" and "B" there
            sta $0400
            stx $0401

            ; Switch to bank 2, get a byte from LOROM and HIROM
            lda #2
            sta EASYFLASH_BANK
            lda $8000
            ldx $a000
            ; and put them to the screen, we should see "A" and "B" there
            sta $0400 + 40
            stx $0401 + 40

            ; effect!
lp2:
            dec $d020
            jmp lp2
        }

        ; fill the whole bank with value $00
        !align $ffff, $a000, $ff
    }

; =============================================================================
; 00:1:0000 (HIROM, bank 0)
bankStart_00_1:
    ; This code runs in Ultimax mode after reset, so this memory becomes
    ; visible at $E000..$FFFF first and must contain a reset vector
    !pseudopc $e000 {
coldStart:
        ; === the reset vector points here ===
        sei
        ldx #$ff
        txs
        cld

        ; copy the final start-up code to RAM (bottom of CPU stack)
        ldx #(startUpEnd - startUpCode)
l1:
        lda startUpCode, x
        sta $0100, x
        dex
        bpl l1
        jmp $0100

startUpCode:
        !pseudopc $0100 {
            ; === this code is copied to the stack area, does some inits ===
            ; === scans the keyboard and kills the cartridge or          ===
            ; === starts the main app                                    ===
            lda #EASYFLASH_16K + EASYFLASH_LED
            sta EASYFLASH_CONTROL

            ; same init stuff the kernel calls after reset
            ldx #0
            stx $d016
            jsr $ff84   ; Initialise I/O

            ; These may not be needed - depending on what you'll do
            jsr $ff87   ; Initialise System Constants
            jsr $ff8a   ; Restore Kernal Vectors
            jsr $ff81   ; Initialize screen editor

            ; Check if one of the magic kill keys is pressed
            ; This should be done in the same way on any EasyFlash cartridge!
            ; we rely on the init functions above to set up the directions
            lda $7f
            sta $dc00   ; pull down row 7
            lda $dc01   ; read coloumns
            ora #$1f    ; only leave "Run/Stop", "Q" and "C="
            tax
            inx         ; $ff => $00 = none of these keys pressed
            bne kill    ; branch if coloums 7 is low => RUN/STOP key

            ; start the application code
            jmp $8000

kill:
            lda #EASYFLASH_KILL
            sta EASYFLASH_CONTROL
            jmp $(fffc)	; reset
        }
startUpEnd:


        ; fill it up to $FFFC to put the reset vector there
        !align $ffff, $fffc, $ff

        ; RESET vector
        !16 coldStart
        !16 $ffff
    }

; =============================================================================
; 01:0:0000 (LOROM, bank 1)
bankStart_01_0:
        ; fill the whole bank with value 1 = 'A'
        !fill $2000, 1

; =============================================================================
; 01:1:0000 (HIROM, bank 1)
bankStart_01_1:
        ; fill the whole bank with value 2 = 'B'
        !fill $2000, 2

; =============================================================================
; 02:0:0000 (LOROM, bank 2)
bankStart_02_0:
        ; fill the whole bank with value 3 = 'C'
        !fill $2000, 3

; =============================================================================
; 02:1:0000 (HIROM, bank 2)
bankStart_02_1:
        ; fill the whole bank with value 4 = 'D'
        !fill $2000, 4
