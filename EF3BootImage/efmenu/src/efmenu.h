/*
 * efmenu.h
 *
 *  Created on: 17.07.2011
 *      Author: skoe
 */

#ifndef EFMENU_H_
#define EFMENU_H_

#include <stdint.h>


#define MODE_EF     0
#define MODE_FC3    1
#define MODE_GEORAM 2
#define MODE_KERNAL 3

#define EF_DIR_BANK         0x10
#define EF_DIR_NUM_SLOTS    16
#define EF_DIR_NUM_KERNALS  8


void __fastcall__ set_slot(uint8_t slot);
void __fastcall__ set_bank(uint8_t bank);
void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode);
void __fastcall__ startProgram(uint8_t bank);

void waitForNoKey(void);

typedef struct efmenu_dir_s
{
    char        signature[16];
    char        slots[EF_DIR_NUM_SLOTS][16];
    char        kernals[EF_DIR_NUM_KERNALS][16];
    uint16_t    checksum;
} efmenu_dir_t;


typedef struct efmenu_entry_s
{
    uint8_t key;
    uint8_t slot;
    uint8_t bank;
    uint8_t mode;
    char    label[3 + 1];
    char    name[16 + 1];
} efmenu_entry_t;


#endif /* EFMENU_H_ */
