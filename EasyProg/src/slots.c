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
#include <string.h>

#include "easyprog.h"
#include "texts.h"
#include "slots.h"
#include "screen.h"
#include "selectbox.h"
#include "util.h"

#define MAX_SLOTS 16
#define MAX_KERNALS 8

uint8_t g_nSelectedSlot;
uint8_t g_nSlots;


/******************************************************************************/
/**
 * Let the user select a slot. Return the slot number.
 * Return 255 if the user canceled the selection.
 */
uint8_t __fastcall__ selectSlotDialog(uint8_t nSlots)
{
	SelectBoxEntry* pEntries;
    SelectBoxEntry* pEntry;
    uint8_t    nSlot, rv;

    pEntries = malloc((MAX_SLOTS + 1) * sizeof(SelectBoxEntry));
    if (!pEntries)
    {
    	screenPrintSimpleDialog(apStrOutOfMemory);
    	return 0;
    }

    pEntry = pEntries;
    for (nSlot = 0; nSlot < nSlots; ++nSlot)
    {
        if (nSlot == 0)
        {
            strcpy(pEntry->label, "System Area");
        }
        else
        {
            strcpy(utilStr, "Slot ");
            utilAppendDecimal(nSlot);
            strcpy(pEntry->label, utilStr);
        }
        ++pEntry;
    }
    pEntry->label[0] = 0; // end marker

    rv = selectBox(pEntries, "a slot to use");
    free(pEntries);
    return rv;
}


/******************************************************************************/
/**
 * Let the user select a KERNAL slot. Return the slot number.
 * Return 255 if the user canceled the selection.
 */
uint8_t selectKERNALSlotDialog(void)
{
    SelectBoxEntry* pEntries;
    SelectBoxEntry* pEntry;
    uint8_t    nSlot, rv;

    pEntries = malloc((MAX_KERNALS + 1) * sizeof(SelectBoxEntry));
    if (!pEntries)
    {
        screenPrintSimpleDialog(apStrOutOfMemory);
        return 0;
    }

    pEntry = pEntries;
    for (nSlot = 0; nSlot < MAX_KERNALS; ++nSlot)
    {
        strcpy(utilStr, "KERNAL ");
        utilAppendDecimal(nSlot);
        strcpy(pEntry->label, utilStr);
        ++pEntry;
    }
    pEntry->label[0] = 0; // end marker

    rv = selectBox(pEntries, "a KERNAL to write");
    free(pEntries);
    return rv;
}


/******************************************************************************/
/**
 * If we have more than one slot, ask the user which one he wants to use.
 * If bWarn != 0 and he selects slot 0, print a warning and repeat the
 * selection.
 **/
void __fastcall__ checkAskForSlot(uint8_t bWarn)
{
    if (g_nSlots > 1)
    {
        for (;;)
        {
            refreshMainScreen();
            g_nSelectedSlot = selectSlotDialog(g_nSlots);
            if (g_nSelectedSlot == 0 && bWarn)
            {
                if (screenPrintDialog(apStrSlot0,
                        BUTTON_ENTER | BUTTON_STOP) == BUTTON_ENTER)
                    break;
            }
            else
                break;
        }
        refreshMainScreen();
    }
}

/******************************************************************************/
/**
 *
 **/
void selectSlot0(void)
{
    if (g_nSlots > 1)
    {
        g_nSelectedSlot = 0;
        refreshMainScreen();
    }
}
