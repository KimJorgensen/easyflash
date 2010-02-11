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
static char m_aBlockStates[2][FLASH_MAX_NUM_BANKS];

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
    progressUpdateDisplay();
}

/******************************************************************************/
/**
 * Update the progress display area, values only.
 */
void progressUpdateDisplay(void)
{
    uint8_t nChip, nBank;

    for (nChip = 0; nChip < 2; ++nChip)
    {
        for (nBank = 0; nBank < FLASH_NUM_BANKS; ++nBank)
            progressDisplayBank(nChip, nBank);
    }
}


/******************************************************************************/
/**
 * Update the value of a single bank in the progress display area.
 *
 */
void __fastcall__ progressDisplayBank(uint8_t nChip, uint8_t nBank)
{
    uint8_t  x, y;

    // when we have more physical banks than shown in the display =>
    // use last visible bank
    if (nBank >= FLASH_NUM_BANKS)
        return;

    y = 17 + nChip * (FLASH_NUM_BANKS / PROGRESS_BANKS_PER_LINE) +
        nBank / PROGRESS_BANKS_PER_LINE;
    x = 6 + nBank % PROGRESS_BANKS_PER_LINE;

    cputcxy(x, y, m_aBlockStates[nChip][nBank]);
}


/******************************************************************************/
/**
 * Set the state of a single bank. The display is updated automatically.
 */
void __fastcall__ progressSetBankState(uint8_t nBank, uint8_t nChip,
                                       uint8_t state)
{
    if ((nBank < FLASH_MAX_NUM_BANKS) && (nChip < 2))
    {
        m_aBlockStates[nChip][nBank] = state;
        progressDisplayBank(nChip, nBank);
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
    uint8_t i;
    for (i = nBank; i < nBank + nBankCount; ++i)
    {
        if ((i < FLASH_MAX_NUM_BANKS) && (nChip < 2))
        {
            m_aBlockStates[nChip][i] = state;
            progressDisplayBank(nChip, i);
        }
    }
}


/******************************************************************************/
/**
 * Get the state of the bank which contains the given address.
 */
uint8_t __fastcall__ progressGetStateAt(uint8_t nBank, uint8_t nChip)
{
    if ((nBank < FLASH_MAX_NUM_BANKS) && (nChip < 2))
    {
        return m_aBlockStates[nChip][nBank];
    }
    return PROGRESS_UNTOUCHED;
}
