 ;
 ; ELoad
 ;
 ; (c) 2011 Thomas Giesel
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
 ; Thomas Giesel skoe@directbox.com
 ;

.include "eload_macros.s"
.include "config.s"
.include "drive_1541_inc.s"

.export drive_code_1541
drive_code_1541:

; =============================================================================
;
; Drive code assembled to fixed address $0300 follows
;
; The code above is uploaded to the drive with KERNAL mechanisms. It has to
; contain everything to transfer the rest of the code using the fast protocol.
;
; =============================================================================
.org $0300
.export drive_code_1541_start
drive_code_1541_start  = *

.export drv_start
drv_start:
        tsx
        stx stack

drv_1541_main:
        cli                     ; allow IRQs when waiting
        jsr drv_load_code       ; does SEI when data is received
        jsr drv_load_overlay
        jsr $0600
        jmp drv_1541_main

;.export drv_1541_wait_rx
;drv_1541_wait_rx:
;        jmp drv_wait_rx

.export drv_1541_recv_to_buffer
drv_1541_recv_to_buffer:
        jmp recv_to_buffer

.export drv_1541_recv
drv_1541_recv:
        jmp recv

.export drv_1541_send
drv_1541_send:
        jmp drv_send

.include "xfer_drive_1mhz.s"

; =============================================================================
;
; Release the IEC bus, restore SP and leave the loader code.
;
; =============================================================================
.export drv_1541_exit
drv_1541_exit:
drv_exit:
        lda #0                        ; release IEC bus
        sta serport
        ldx stack
        txs
        cli
        rts

.export drive_code_init_size_1541: abs
drive_code_init_size_1541  = * - drive_code_1541_start
.assert drive_code_init_size_1541 <= 256, error, "drive_code_init_size_1541"

.reloc
