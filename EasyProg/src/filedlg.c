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

#define FILEDLG_X 6
#define FILEDLG_Y 4
#define FILEDLG_W 29
#define FILEDLG_H 18


/******************************************************************************/

// A table with strings for all directory entry types
static const char* apStrEntryType[] =
{
	"DEL", "SEQ", "PRG", "USR", "REL", "-5-", "DIR", "-7-", "VRP"
};

/******************************************************************************/
/** Local data: Put here to reduce code size */

// buffer for directory entries
//static struct cbm_dirent* aDirEntries;
static struct cbm_dirent aDirEntries[FILEDLG_ENTRIES];

// number of directory entries in the buffer
static uint16_t nDirEntries;

static uint8_t  nSelection;

/******************************************************************************/
/**
 * Compare function for qsort
 */
static int fileDlgCompareEntries(const void* a, const void* b)
{
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

	if (cbm_opendir(FILEDLG_LFN, 8))
	{
		cputsxy(0, 0, "opendir failed");
		for (;;);
	}

	pEntry = aDirEntries;
	nDirEntries = 0;
	while ((!cbm_readdir(FILEDLG_LFN, pEntry)) &&
           (nDirEntries < FILEDLG_ENTRIES))
	{
		// only accept known file types (I do not know VRP...)
		if (pEntry->type < CBM_T_VRP)
		{
			++pEntry;
		}
	}
	nDirEntries = pEntry - aDirEntries;

  	cbm_closedir(FILEDLG_LFN);

	qsort(aDirEntries, nDirEntries, sizeof(aDirEntries[0]),
          fileDlgCompareEntries);
}


/******************************************************************************/
/**
 */
static void fileDlgPrintEntry(uint8_t nLine, uint8_t nEntry)
{
    struct cbm_dirent* pEntry;

    pEntry = aDirEntries + nEntry;

    gotoxy(FILEDLG_X + 1, FILEDLG_Y + 1 + nLine);

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

    if (rv == 0)
    {
        cbm_close(15);
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
            for (n = 0; n < FILEDLG_H - 2; ++n)
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
                    gotoxy(FILEDLG_X + 1, FILEDLG_Y + 1 + n);
                    cclear(FILEDLG_W - 2);
                }
            }
        }
        else
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
            if (nSelection < nDirEntries - 1)
            {
                ++nSelection;
                if (nSelection > nTopLine + FILEDLG_H - 3)
                {
                    nTopLine += FILEDLG_H - 2;
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
        }
    }
}
