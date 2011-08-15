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
#include "buffer.h"
#include "texts.h"
#include "slots.h"
#include "screen.h"
#include "selectbox.h"
#include "util.h"

#define MAX_SLOTS 16


/******************************************************************************/
/**
 * Let the user select a slot. Return the slot number.
 * Return 255 if the user canceled the selection.
 */
uint8_t __fastcall__ selectSlot(uint8_t nSlots)
{
	SelectBoxEntry* pEntries;
    SelectBoxEntry* pEntry;
    uint8_t    nSlot, rv;

    pEntries = malloc(MAX_SLOTS * sizeof(SelectBoxEntry));
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
    pEntry->label[nSlot] = 0; // end marker

    rv = selectBox(pEntries, "a slot to use");
    free(pEntries);
    return rv;
}
