/*
 * EasyProg - filedlg.c - File open dialog
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
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <cbm.h>

#include "screen.h"

#define FILEDLG_ENTRIES 128
#define FILEDLG_LFN     72

#define FILEDLG_X 5
#define FILEDLG_Y 4
#define FILEDLG_W 29
#define FILEDLG_H 18

#define FILEDLG_Y_ENTRIES (FILEDLG_Y + 3)
#define FILEDLG_N_ENTRIES (FILEDLG_H - 4)


/******************************************************************************/

// A table with strings for all directory entry types
static const char* apStrEntryType[] =
{
	"DEL", "SEQ", "PRG", "USR", "REL", "-5-", "DIR", "-7-", "VRP"
};

// change directory up one level
static const char strUp[] = { 95, 0 }; // arrow left

// current drive
static uint8_t deviceNumber = 8;


/******************************************************************************/
/** Local data: Put here to reduce code size */

// buffer for directory entries
//static struct cbm_dirent* aDirEntries;
static struct cbm_dirent aDirEntries[FILEDLG_ENTRIES];

// number of directory entries in the buffer
static uint8_t nDirEntries;

static uint8_t nSelection;

/******************************************************************************/
/**
 * Compare function for qsort
 */
static int fileDlgCompareEntries(const void* a, const void* b)
{
    // arrow left must be the first entry
    if (((struct cbm_dirent*)a)->name[0] == 95)
        return -1;
    if (((struct cbm_dirent*)b)->name[0] == 95)
        return 1;

	return strcmp(((struct cbm_dirent*)a)->name,
                  ((struct cbm_dirent*)b)->name);
}

/******************************************************************************/
/**
 * Read the directory into the buffer and set the number of entries.
 */
static void fileDlgReadDir(void)
{
    struct cbm_dirent* pEntry;
    uint8_t bHaveParent;

    nDirEntries = 0;
    bHaveParent = 0;
    pEntry = aDirEntries;

    if (cbm_opendir(FILEDLG_LFN, deviceNumber))
    {
        cbm_closedir(FILEDLG_LFN);
        return;
    }

    // read entries, but leave one slot free for "<-", see below
    while ((!cbm_readdir(FILEDLG_LFN, pEntry)) && (nDirEntries
            < FILEDLG_ENTRIES - 1))
    {
        // only accept supported file types but not directory ".."
        if ((pEntry->type == CBM_T_DIR) ||
            (pEntry->type == CBM_T_PRG))
        {
            ++pEntry;
            ++nDirEntries;
        }

        // On vice we have "..", don't add "<-"
        if (pEntry->type == CBM_T_DIR && !strcmp(pEntry->name, ".."))
            bHaveParent = 1;
    }

    cbm_closedir(FILEDLG_LFN);

    if (!bHaveParent)
    {
        // add "<-" (arrow left) for parent directory
        strcpy(pEntry->name, strUp);
        pEntry->size = 0;
        pEntry->type = CBM_T_DIR;
        ++pEntry;
        ++nDirEntries;
    }

    qsort(aDirEntries, nDirEntries, sizeof(aDirEntries[0]),
          fileDlgCompareEntries);
}


/******************************************************************************/
/**
 * Print/Update the file dialog of the headline
 */
static void fileDlgHeadline(void)
{
    gotoxy(FILEDLG_X + 1, FILEDLG_Y + 1);
    cprintf("Select CRT file        %d ", deviceNumber);
}


/******************************************************************************/
/**
 */
static void fileDlgPrintEntry(uint8_t nLine, uint8_t nEntry)
{
    struct cbm_dirent* pEntry;

    pEntry = aDirEntries + nEntry;

    gotoxy(FILEDLG_X + 1, FILEDLG_Y_ENTRIES + nLine);

    if (nEntry == nSelection)
        revers(1);

    cprintf("%5d %-16s %s", pEntry->size, pEntry->name,
        apStrEntryType[pEntry->type]);

    revers(0);
}


/******************************************************************************/
/**
 * Enter the relative directory given.
 *
 * return 1 for success, 0 for failure.
 */
uint8_t fileDlgChangeDir(const char* pStrDir)
{
    uint8_t rv;
    char strCmd[3 + FILENAME_MAX];

    strcpy(strCmd, "cd:");
    strcpy(strCmd + 3, pStrDir);

    rv = cbm_open (15, 8, 15, strCmd);
    cbm_close(15);

    if (rv == 0)
    {
        return 1;
    }

    // error
    return 0;
}


/******************************************************************************/
/**
 * Show a file open dialog. If the user selects a file, copy the name to
 * pStrSelected.
 *
 * return 1 if the user selected a file, 0 if he canceled the dialog.
 */
uint8_t fileDlg(char* pStrName)
{
    unsigned char nTopLine;
    unsigned char n, nEntry, nOldSelection;
    unsigned char bRefresh, bReload;
    char key;
    struct cbm_dirent* pEntry;

    screenPrintBox(FILEDLG_X, FILEDLG_Y, FILEDLG_W, FILEDLG_H);
    screenPrintSepLine(FILEDLG_X, FILEDLG_X + FILEDLG_W - 1, FILEDLG_Y + 2);

    bReload = 1;
    for (;;)
    {
        if (bReload)
        {
            bReload = 0;
            bRefresh = 1;
            nSelection = 0;
            nTopLine = 0;
            fileDlgReadDir();
        }

        if (bRefresh)
        {
            bRefresh = 0;
            fileDlgHeadline();
            for (n = 0; n < FILEDLG_N_ENTRIES; ++n)
            {
                // is there an entry for this display line?
                if (n + nTopLine < nDirEntries)
                {
                    // yes, print it
                    nEntry = n + nTopLine;
                    fileDlgPrintEntry(n, nEntry);
                }
                else
                {
                    gotoxy(FILEDLG_X + 1, FILEDLG_Y_ENTRIES + n);
                    cclear(FILEDLG_W - 2);
                }
            }
        }
        else if (nDirEntries)
        {
            // only refresh the two lines which have changed
            fileDlgPrintEntry(nOldSelection - nTopLine, nOldSelection);
            fileDlgPrintEntry(nSelection - nTopLine, nSelection);
        }

        nOldSelection = nSelection;
        key = cgetc();
        switch (key)
        {
        case CH_CURS_UP:
            if (nSelection)
            {
                --nSelection;
                if (nSelection < nTopLine)
                {
                    if (nTopLine > FILEDLG_H - 2)
                        nTopLine -= FILEDLG_H - 2;
                    else
                        nTopLine = 0;
                    bRefresh = 1;
                }
            }
            break;

        case CH_CURS_DOWN:
            if (nSelection + 1 < nDirEntries)
            {
                ++nSelection;
                if (nSelection > nTopLine + FILEDLG_N_ENTRIES - 1)
                {
                    fileDlgPrintEntry(nOldSelection - nTopLine, nOldSelection);
                    nTopLine += FILEDLG_H - 4;
                    bRefresh = 1;
                }
            }
            break;

        case CH_ENTER:
            pEntry = aDirEntries + nSelection;
            switch (pEntry->type)
            {
            case CBM_T_DIR:
                if (fileDlgChangeDir(pEntry->name))
                    bReload = 1;
                break;

            case CBM_T_PRG:
                strcpy(pStrName, pEntry->name);
                return 1;
            }
            break;

        case CH_STOP:
            return 0;

        default:
            if (key >= '0' && key <= '9')
            {
                if (key >= '8')
                {
                    deviceNumber = key - '0';
                }
                else
                    deviceNumber = 10 + key - '0';

                fileDlgHeadline();
                bReload = 1;
            }
        }
    }
}
