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
#include <string.h>
#include <stdint.h>
#include <6502.h>

#include "screen.h"
#include "texts.h"
#include "eftest.h"
#include "torturetest.h"
#include "buffer.h"

#define KERNAL_ADDR ((uint8_t*)0xe000)
#define KERNAL_SIZE 0x2000

static char strDetails[41];



static void testKernalCreatePattern(uint8_t nTestLoop)
{
    uint16_t offset;
    for (offset = 0; offset < KERNAL_SIZE; ++offset)
    {
        BUFFER_TEST_PATTERN_ADDR[offset] =
                offset + nTestLoop - (offset >> 8);
    }
}

static uint8_t kernalCompare(uint8_t* p1, uint8_t* p2)
{
    uint16_t offset;
    for (offset = 0; offset < KERNAL_SIZE; ++offset)
    {
        if (*p1 != *p2)
        {
            sprintf(strDetails, "at offset $%04x: 0x%02x != 0x%02x",
                    offset, *p1, *p2);
            return 1;
        }
        ++p1;
        ++p2;
    }
    return 0;
}


void kernalRamTest(void)
{
    uint8_t nTestLoop;

    strDetails[0] = '\0';
    memcpy(BUFFER_KERNAL_COPY_ADDR, KERNAL_ADDR, KERNAL_SIZE);
    nTestLoop = 0;
    SEI();

    for (;;)
    {
        bufferHideLowROM();
        setStatusLine("Create test pattern");
        testKernalCreatePattern(nTestLoop);

        setStatusLine("Check real Kernal");
        if (kernalCompare(BUFFER_KERNAL_COPY_ADDR, KERNAL_ADDR))
            goto error;

        setStatusLine("Copy test pattern");
        memcpy(KERNAL_ADDR, BUFFER_TEST_PATTERN_ADDR, KERNAL_SIZE);

        setStatusLine("Check test pattern");
        bufferHideAllROMs();
        if (kernalCompare(BUFFER_TEST_PATTERN_ADDR, KERNAL_ADDR))
            goto error;

        ++nTestLoop;
    }

error:
    bufferShowAllROMs();
    CLI();
    screenPrintTwoLinesDialog("Test failed", strDetails);
}
