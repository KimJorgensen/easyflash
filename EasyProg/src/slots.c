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
#include "eapiglue.h"
#include "texts.h"
#include "flash.h"
#include "slots.h"
#include "screen.h"
#include "selectbox.h"
#include "util.h"

#define MAX_KERNALS 8

uint8_t g_nSelectedSlot;
uint8_t g_nSlots;

// copy of EF directory in RAM
static efmenu_dir_t m_EFDir;

static const char* m_pEFSignature = "EF-Directory V1:";

/******************************************************************************/
/**
 * Read the directory from EasyFlash to m_EFDir. If there is no valid
 * directory in the cartridge, initialize the structure with defaults.
 */
void slotsFillEFDir(void)
{
    uint8_t i;

    eapiReInit();
    eapiSetSlot(EF_DIR_SLOT);
    eapiSetBank(EF_DIR_BANK);

    efCopyCartROM(&m_EFDir, (void*)(0x8000), sizeof(m_EFDir));
    if (memcmp(m_EFDir.signature,
               m_pEFSignature, sizeof(m_EFDir.signature)) != 0)
    {
        // initialize new directory
        memcpy(m_EFDir.signature,
                m_pEFSignature, sizeof(m_EFDir.signature));
        for (i = 1; i < EF_DIR_NUM_SLOTS; ++i)
        {
            strcpy(utilStr, "Slot ");
            utilAppendDecimal(i);
            strcpy(m_EFDir.slots[i], utilStr);
        }
        for (i = 0; i < EF_DIR_NUM_KERNALS; ++i)
        {
            strcpy(utilStr, "Kernal ");
            utilAppendDecimal(i + 1);
            strcpy(m_EFDir.kernals[i], utilStr);
        }
    }

    // slot 0 always gets this name
    strcpy(m_EFDir.slots[0], "System Area");
}

/******************************************************************************/
/**
 * Let the user select a slot. Return the slot number.
 * Return ~0 if the user canceled the selection.
 */
uint8_t __fastcall__ selectSlotDialog(uint8_t nSlots)
{
	SelectBoxEntry* pEntries;
    SelectBoxEntry* pEntry;
    uint8_t    nSlot, rv;

    slotsFillEFDir();
    pEntries = malloc((FLASH_MAX_SLOTS + 1) * sizeof(SelectBoxEntry));
    if (!pEntries)
    {
    	screenPrintSimpleDialog(apStrOutOfMemory);
    	return 0;
    }

    // termination for strings with strlen() == 16
    // and termination for list
    memset(pEntries, 0, (FLASH_MAX_SLOTS + 1) * sizeof(SelectBoxEntry));

    for (nSlot = 0; nSlot < nSlots; ++nSlot)
    {
        pEntry = pEntries + nSlot;
        // take care: target must be at least as large as source
        memcpy(pEntry->label, m_EFDir.slots[nSlot],
               sizeof(m_EFDir.slots[0]));
        // empty slots get a '-' because the menu needs a string
        if (pEntry->label[0] == 0)
            pEntry->label[0] = '-';
    }

    rv = selectBox(pEntries, "a slot to use");
    free(pEntries);
    return rv;
}


/******************************************************************************/
/**
 * Let the user select a KERNAL slot. Return the slot number.
 * Return ~0 if the user canceled the selection.
 */
uint8_t selectKERNALSlotDialog(void)
{
    SelectBoxEntry* pEntries;
    SelectBoxEntry* pEntry;
    char*           pLabel;
    uint8_t         nSlot, rv;

    slotsFillEFDir();
    pEntries = malloc((MAX_KERNALS + 1) * sizeof(SelectBoxEntry));
    if (!pEntries)
    {
        screenPrintSimpleDialog(apStrOutOfMemory);
        return 0;
    }

    // termination for strings with strlen() == 16
    // and termination for list
    memset(pEntries, 0, (FLASH_MAX_SLOTS + 1) * sizeof(SelectBoxEntry));

    pEntry = pEntries;
    pLabel = m_EFDir.kernals[0];
    for (nSlot = 1; nSlot <= MAX_KERNALS; ++nSlot)
    {
        // take care: target must be at least as large as source
        memcpy(pEntry->label, pLabel, sizeof(m_EFDir.kernals[0]));
        // empty slots get a '-' because the menu needs a string
        if (pEntry->label[0] == 0)
            pEntry->label[0] = '-';

        ++pEntry;
        pLabel += sizeof(m_EFDir.kernals[0]);
    }

    rv = selectBox(pEntries, "a KERNAL slot");
    free(pEntries);
    return rv;
}


/******************************************************************************/
/**
 * If we have more than one slot, ask the user which one he wants to use.
 *
 * Return 0 if the user canceled the selection.
 **/
uint8_t __fastcall__ checkAskForSlot(void)
{
    uint8_t s;

    if (g_nSlots > 1)
    {
        for (;;)
        {
            refreshMainScreen();
            s = selectSlotDialog(g_nSlots);
            if (s == ~0)
                return 0;

            g_nSelectedSlot = s;
            if (g_nSelectedSlot == 0)
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
    return 1;
}

/******************************************************************************/
/**
 * This sets g_nSelectedSlot and refreshes the main screen, but does not
 * write to the I/O register yet.
 **/
void __fastcall__ slotSelect(uint8_t slot)
{
    g_nSelectedSlot = slot;
    if (g_nSlots > 1)
    {
        refreshMainScreen();
    }
}
