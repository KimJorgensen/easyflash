/*
 * EasyProg - torturetest.c - Torture Test
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

#include <conio.h>
#include <string.h>
#include <stdio.h>

#include "screen.h"
#include "texts.h"
#include "eftest.h"
#include "torturetest.h"

/*
 * The cartridge test works like this:
 * - Each bank (8 KiB) is filled with a special pattern:
 *   2k bank number
 *   2k 0xaa
 *   2k 0x55
 *   1k 0x00 - 0xff (repeated)
 *   1k 0xff - 0x00 (repeated)
 */

// static because my heap doesn't work yet
// The buffer must always be 256 bytes long
static uint8_t buffer[256];

void tortureTest(void)
{
    uint16_t rv;

    screenPrintSimpleDialog(apStrTestEndless);
    refreshMainScreen();
    setStatus("Testing...");

    for (;;)
    {
    	*(uint8_t*)0xd020 = COLOR_FOREGROUND;
    	*(uint8_t*)0xd020 = COLOR_BACKGROUND;
        if (!tortureTestCheckRAM())
        {
            screenPrintSimpleDialog(apStrBadRAM);
            return;
        }
    }
}
