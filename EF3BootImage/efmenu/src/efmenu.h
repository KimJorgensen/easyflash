/*
 * efmenu.h
 *
 * EasyFash 3 Menu version 1.3.0, May 2018, are
 * Copyright (c) 2018 Kim Jorgensen, are derived from EasyFash 3 Menu 1.2.0,
 * and are distributed according to the same disclaimer and license as
 * EasyFash 3 Menu 1.2.0
 *
 * EasyFash 3 Menu versions 1.0.4, January 2012, through 1.2.0, February 2013, are
 * Copyright (c) 2012-2013 Thomas Giesel
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
 */

#ifndef EFMENU_H_
#define EFMENU_H_

#include <stdint.h>


#define MODE_EF             0
#define MODE_EF_NO_RESET    1
#define MODE_KERNAL         2
#define MODE_FC3            3
#define MODE_AR             4
#define MODE_SS5            5
#define MODE_GO128          6
#define MODE_KILL           7
/* dummy modes */
#define MODE_SHOW_VERSION   128
#define MODE_NEXT_PAGE      129


#define EF_DIR_NUM_SLOTS    16
#define EF_DIR_NUM_KERNALS  8
#define EF_DIR_NUM_FREEZERS 4
#define EF_DIR_SLOT         0
#define EF_DIR_BANK         0x10
#define EF_DIR_ENTRY_SIZE   16

#define EF3_OLD_VERSION  0xa1
#define EF3_CPLD_VERSION (*(uint8_t*) 0xde08)

void __fastcall__ set_slot(uint8_t slot);
void __fastcall__ set_bank(uint8_t bank);
void __fastcall__ set_bank_change_mode(uint8_t bank, uint8_t mode);
void __fastcall__ start_program(uint8_t bank);

void wait_for_no_key(void);
uint8_t is_c128(void);
uint8_t shift_pressed(void);

void joy_init_irq(void);

typedef struct efmenu_dir_s
{
    char        signature[16];
    char        slots[EF_DIR_NUM_SLOTS][EF_DIR_ENTRY_SIZE];
    char        kernals[EF_DIR_NUM_KERNALS][EF_DIR_ENTRY_SIZE];
    char        freezers[EF_DIR_NUM_FREEZERS][EF_DIR_ENTRY_SIZE];
    uint8_t     boot_mode;
    uint16_t    checksum;
} efmenu_dir_t;


typedef struct efmenu_entry_s
{
    uint8_t key;
    uint8_t slot;
    uint8_t bank;
    uint8_t chip;
    uint8_t mode;
    char    label[3 + 1];
    char    name[16 + 1];
    char    type[3 + 1];
} efmenu_entry_t;


typedef struct efmenu_s
{
    uint8_t          n_page;
    uint16_t         x_pos;
    uint8_t          y_pos;
    uint8_t          n_max_entries;
    efmenu_entry_t*  pp_entries;
} efmenu_t;


#endif /* EFMENU_H_ */
