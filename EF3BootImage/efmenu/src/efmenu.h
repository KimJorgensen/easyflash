/*
 * efmenu.h
 *
 *  Created on: 17.07.2011
 *      Author: skoe
 */

#ifndef EFMENU_H_
#define EFMENU_H_

typedef struct efmenu_entry_s
{
    uint8_t     key;
    uint8_t     bank;
    uint8_t     mode;
    char        label[3 + 1];
    char        name[16 + 1];
} efmenu_entry_t;


#endif /* EFMENU_H_ */
