/*
 * EasyProg - progress.c - The progress display area
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

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <conio.h>

#include "flash.h"
#include "screen.h"
#include "progress.h"

/******************************************************************************/
/* Static variables */

// Array with the state of all banks on high and low flash.
static char m_aBlockStates[2][FLASH_NUM_BANKS];

/******************************************************************************/
/**
 * Set the state of all blocks to "untouched".
 */
void progressInit(void)
{
    memset(m_aBlockStates, PROGRESS_UNTOUCHED, sizeof(m_aBlockStates));
}

/******************************************************************************/
/**
 * Show the progress display area including box etc.
 */
void progressShow(void)
{
    uint8_t  y = 16;

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(5, y++, PROGRESS_BANKS_PER_LINE + 2,
                   2 * FLASH_NUM_BANKS / PROGRESS_BANKS_PER_LINE + 2);
    textcolor(COLOR_FOREGROUND);

    cputsxy(2, y, "Lo:");
    cputsxy(2, y + 2, "Hi:");
    progressUpdate();
}

/******************************************************************************/
/**
 * Update the progress display area, values only.
 */
void progressUpdate(void)
{
    uint8_t  y = 17;
    uint8_t  i;
    uint8_t  line;
    char*    p;

    p = m_aBlockStates[0];
    for (line = 2 * FLASH_NUM_BANKS / PROGRESS_BANKS_PER_LINE; line; --line)
    {
        gotoxy(6, y++);
        for (i = PROGRESS_BANKS_PER_LINE; i; --i)
            cputc(*p++);
    }
}


/******************************************************************************/
/**
 * Set the state of a certain bank. The display is updated automatically.
 */
void __fastcall__ progressSetBankState(uint8_t nBank, uint8_t nChip,
                                       uint8_t state)
{
    if ((nBank < FLASH_NUM_BANKS) && (nChip < 2))
    {
        m_aBlockStates[nChip][nBank] = state;
        progressUpdate();
    }
}


/******************************************************************************/
/**
 * Set the state of a several banks. The display is updated automatically.
 */
void __fastcall__ progressSetMultipleBanksState(uint8_t nBank, uint8_t nChip,
                                                uint8_t nBankCount,
                                                uint8_t state)
{
    int i;
    for (i = nBank; i < nBank + nBankCount; ++i)
    {
        if ((i < FLASH_NUM_BANKS) && (nChip < 2))
        {
            m_aBlockStates[nChip][i] = state;
        }
    }
    progressUpdate();
}


/******************************************************************************/
/**
 * Get the state of the bank which contains the given address.
 */
uint8_t __fastcall__ progressGetStateAt(uint8_t nBank, uint8_t nChip)
{
    if ((nBank < FLASH_NUM_BANKS) && (nChip < 2))
    {
        return m_aBlockStates[nChip][nBank];
    }
    return PROGRESS_UNTOUCHED;
}
