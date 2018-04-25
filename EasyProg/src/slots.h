/*
 * EasyProg - slots.h
 *
 * EasyProg version 1.8.0, April 2018, are
 * Copyright (c) 2018 Kim Jorgensen, are derived from EasyProg 1.7.1,
 * and are distributed according to the same disclaimer and license as
 * EasyProg 1.7.1
 *
 * EasyProg versions 1.2 September 2009, through 1.7.1, September 2013, are
 * Copyright (c) 2009-2013 Thomas Giesel
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Thomas Giesel skoe@directbox.com
 */

#ifndef SLOTS_H
#define SLOTS_H

#include <stdint.h>

#define EF_DIR_NUM_SLOTS    16
#define EF_DIR_NUM_KERNALS  8
#define EF_DIR_NUM_FREEZERS 4
#define EF_DIR_SLOT         0
#define EF_DIR_BANK         0x10
#define EF_DIR_ENTRY_SIZE   16

#define EF_SLOTS            0
#define KERNAL_SLOTS        1
#define FREEZER_SLOTS       2

void slotsFillEFDir(void);
uint8_t __fastcall__ selectSlotTypeDialog(void);
uint8_t __fastcall__ selectKERNALSlotDialog(void);
uint8_t __fastcall__ selectFreezerSlotDialog(void);
uint8_t __fastcall__ checkAskForEFSlot(void);
void __fastcall__ slotSelect(uint8_t slot);
void __fastcall__ slotSaveName(const char* name, uint8_t nKERNAL, uint8_t nFreezer);
void slotsEditDirectory(void);

extern uint8_t g_nSelectedSlot;
extern uint8_t g_nSlots;

void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode);
void __fastcall__ startProgram(uint8_t bank);

void waitForNoKey(void);

typedef struct efmenu_dir_s
{
    char        signature[16];
    char        slots[EF_DIR_NUM_SLOTS][EF_DIR_ENTRY_SIZE];
    char        kernals[EF_DIR_NUM_KERNALS][EF_DIR_ENTRY_SIZE];
    char        freezers[EF_DIR_NUM_FREEZERS][EF_DIR_ENTRY_SIZE];
    uint8_t     boot_mode;
    uint16_t    checksum;
} efmenu_dir_t;

#endif
