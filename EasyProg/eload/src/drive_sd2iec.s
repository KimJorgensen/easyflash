

.export drive_code_sd2iec
drive_code_sd2iec  = *

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; =============================================================================
.org $0300

.byte "eload1"

.reloc

.export drive_code_size_sd2iec
drive_code_size_sd2iec  = * - drive_code_sd2iec
