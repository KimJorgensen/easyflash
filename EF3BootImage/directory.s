
* = $0000

; 16 bytes signature
!pet "EF-Directory V1:"

; 16 EasyFlash slots
!byte 0                 ; slot 0
!align 15, 0, 0
!pet "Testeintrag"      ; slot 1
!align 15, 0, 0
!byte 0                 ; slot 2
!align 15, 0, 0
!byte 0                 ; slot 3
!align 15, 0, 0
!byte 0                 ; slot 4
!align 15, 0, 0
!byte 0                 ; slot 5
!align 15, 0, 0
!byte 0                 ; slot 6
!align 15, 0, 0
!byte 0                 ; slot 7
!align 15, 0, 0
!byte 0                 ; slot 8
!align 15, 0, 0
!byte 0                 ; slot 9
!align 15, 0, 0
!byte 0                 ; slot 10
!align 15, 0, 0
!byte 0                 ; slot 11
!align 15, 0, 0
!byte 0                 ; slot 12
!align 15, 0, 0
!byte 0                 ; slot 13
!align 15, 0, 0
!byte 0                 ; slot 14
!align 15, 0, 0
!byte 0                 ; slot 15
!align 15, 0, 0

; 8 KERNAL slots
!pet "EXOS V3"          ; KERNAL 1
!align 15, 0, 0
!pet "Beast System"     ; KERNAL 2
!align 15, 0, 0
!pet "Turbo Tape"       ; KERNAL 3
!align 15, 0, 0
!byte 0                 ; KERNAL 4
!align 15, 0, 0
!byte 0                 ; KERNAL 5
!align 15, 0, 0
!byte 0                 ; KERNAL 6
!align 15, 0, 0
!byte 0                 ; KERNAL 7
!align 15, 0, 0
!byte 0                 ; KERNAL 8
