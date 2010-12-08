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

// If this flag is set in a menu entry, it needs a known flash type
#define EASYPROG_MENU_FLAG_NEEDS_FLASH 1


/// This structure contains an EasyFlash address 00:0:0000
typedef struct EasyFlashAddr_s
{
    uint8_t     nBank;
    uint8_t     nChip;
    uint16_t    nOffset;
}
EasyFlashAddr;


extern uint8_t bFastLoaderEnabled;


uint8_t checkFlashType(void);
void __fastcall__ setStatus(const char* pStrStatus);
void refreshMainScreen(void);

#endif /* EASYPROG_H_ */
