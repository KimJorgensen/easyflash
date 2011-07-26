/*
 * EasyProg - filedlg.c - File open dialog
 *
 * (c) 2011 Thomas Giesel
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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>

#include "easyprog.h"
#include "buffer.h"
#include "screen.h"
#include "texts.h"
#include "slots.h"
#include "util.h"

#define MAX_SLOTS 16

#define FILEDLG_X 6
#define FILEDLG_W 28

static void fileDlgPrintFrame(uint8_t nSlots);

/******************************************************************************/
/** Local data: Put here to reduce code size */

// buffer for entries
static SlotEntry* aEntries;

static uint8_t yPosition;
static uint8_t nSelection;

/******************************************************************************/
/**
 * Print/Update the headline
 */
static void __fastcall__ slotsHeadline(const char* pStrAction)
{
    strcpy(utilStr, "Select a slot to ");
    utilAppendStr(pStrAction);
    cputsxy(FILEDLG_X + 1, yPosition + 1, utilStr);
}


/******************************************************************************/
/**
 * Print/Update the frame
 */
static void slotsPrintFrame(uint8_t nSlots)
{
    screenPrintBox(FILEDLG_X, yPosition, FILEDLG_W, nSlots + 6);
    screenPrintSepLine(FILEDLG_X, FILEDLG_X + FILEDLG_W - 1, yPosition + 2);
    screenPrintSepLine(FILEDLG_X, FILEDLG_X + FILEDLG_W - 1, yPosition + nSlots + 6 - 3);
    cputsxy(FILEDLG_X + 1, yPosition + nSlots + 6 - 2, "Up/Down/Stop/Enter");
}


/******************************************************************************/
/**
 */
static void slotsFillDirectory(uint8_t nSlots)
{
    uint8_t    nSlot;
    SlotEntry* pEntry;

    pEntry = aEntries;
    for (nSlot = 0; nSlot < nSlots; ++nSlot)
    {
        if (nSlot == 0)
        {
            strcpy(pEntry->name, "System Area");
        }
        else
        {
            strcpy(utilStr, "Slot ");
            utilAppendDecimal(nSlot);
            strcpy(pEntry->name, utilStr);
        }
        ++pEntry;
    }
}


/******************************************************************************/
/**
 */
static void __fastcall__ slotsPrintEntry(uint8_t nEntry)
{
    SlotEntry* pEntry;

    pEntry = aEntries + nEntry;
    gotoxy(FILEDLG_X + 1, yPosition + 3 + nEntry);

    if (nEntry == nSelection)
        revers(1);

    // clear line
    cclear(FILEDLG_W - 2);

    // entry number
    utilStr[0] = 0;
    utilAppendDecimal(nEntry);
    gotox(FILEDLG_X + 5 - strlen(utilStr));
    cputs(utilStr);

    // name
    gotox(FILEDLG_X + 6);
    cputs(pEntry->name);

    revers(0);
}


/******************************************************************************/
/**
 */
uint8_t __fastcall__ selectSlot(uint8_t nSlots)
{
    unsigned char n, nEntry, nOldSelection;
    char key;
    uint8_t rv, bRefresh;
    SlotEntry* pEntry;

    yPosition = 9 - nSlots / 2;

    slotsPrintFrame(nSlots);
    slotsHeadline("use");

    aEntries = SLOT_DIR_ADDR;
    rv = 0;
    bRefresh = 1;
    nSelection = 0;

    slotsFillDirectory(nSlots);
    for (n = 0; n < nSlots; ++n)
    {
        slotsPrintEntry(n);
    }

    for (;;)
    {
        if (bRefresh)
        {
            // only refresh the two lines which have changed
            slotsPrintEntry(nOldSelection);
            slotsPrintEntry(nSelection);
            bRefresh = 0;
        }

        nOldSelection = nSelection;
        key = cgetc();
        switch (key)
        {
        case CH_CURS_UP:
            if (nSelection)
            {
                --nSelection;
                bRefresh = 1;
            }
            break;

        case CH_CURS_DOWN:
            if (nSelection + 1 < nSlots)
            {
                ++nSelection;
                bRefresh = 1;
            }
            break;

        case CH_ENTER:
            pEntry = aEntries + nSelection;
            //strcpy(g_strFileName, pEntry->name);
            rv = 1;
            goto end; // yeah!
            break;

        case CH_STOP:
            goto end; // yeah!
        }
    }
end:
    return rv;
}
