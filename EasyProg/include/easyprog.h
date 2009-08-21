/*
 * EasyProg - easyprog.h - The main module
 *
 * (c) 2009 Thomas Giesel
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
#ifndef EASYPROG_H_
#define EASYPROG_H_

#include <stdint.h>

/// These are the menu entry IDs, they are also index into apStrMenuEntries
typedef enum EasyFlashMenuId_e
{
    // 0 is invalid
    EASYPROG_MENU_ENTRY_WRITE_CRT = 1,
    EASYPROG_MENU_ENTRY_CHECK_TYPE,
    EASYPROG_MENU_ENTRY_ERASE_ALL,
    EASYPROG_MENU_ENTRY_HEX_VIEWER,
    EASYPROG_MENU_ENTRY_TORTURE_TEST,
    EASYPROG_MENU_ENTRY_QUIT,
    EASYPROG_MENU_ENTRY_ABOUT
}
EasyFlashMenuId;

/// This structure contains an EasyFlash address 00:0:0000
typedef struct EasyFlashAddr_s
{
    uint8_t     nBank;
    uint8_t     nChip;
    uint16_t    nOffset;
}
EasyFlashAddr;

void __fastcall__ setStatus(const char* pStrStatus);
void refreshMainScreen(void);

extern char strFileName[];

#endif /* EASYPROG_H_ */
