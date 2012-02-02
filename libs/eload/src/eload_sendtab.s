
.export sendtab

.rodata

        .align 16
sendtab:
        .byte $00, $80, $20, $a0
        .byte $40, $c0, $60, $e0
        .byte $10, $90, $30, $b0
        .byte $50, $d0, $70, $f0
sendtab_end:
        .assert >(sendtab_end - 1) = >sendtab, error, "sendtab mustn't cross page boundary"
        ; If you get this error, you linker config may need something like this:
        ; RODATA:   load = RAM, type = ro, align = $10;
