/*
 * efmenu.h
 *
 *  Created on: 17.07.2011
 *      Author: skoe
 */

#ifndef EFMENU_H_
#define EFMENU_H_

#include <stdint.h>

void __fastcall__ set_bank(uint8_t bank);
void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode);
void waitForNoKey(void);

typedef struct efmenu_entry_s
{
    uint8_t     key;
    uint8_t     bank;
    uint8_t     mode;
    char        label[3 + 1];
    const char* name;
} efmenu_entry_t;


#endif /* EFMENU_H_ */
