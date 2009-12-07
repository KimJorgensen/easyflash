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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <cbm.h>
#include <sprites.h>

#include "easyprog.h"
#include "buffer.h"
#include "screen.h"
#include "texts.h"
#include "dir.h"
#include "util.h"

#define FILEDLG_MAX_ENTRIES 255
#define FILEDLG_LFN     72

#define FILEDLG_X 6
#define FILEDLG_Y 3
#define FILEDLG_W 28
#define FILEDLG_H 19

#define FILEDLG_Y_ENTRIES (FILEDLG_Y + 3)
#define FILEDLG_N_ENTRIES (FILEDLG_H - 6)


static void fileDlgPrintFrame(void);


/******************************************************************************/

// change directory up one level
static const char strUp[] = { 95, 0 }; // arrow left

// current drive
static uint8_t nDriveNumber;


/******************************************************************************/
/** Local data: Put here to reduce code size */

// buffer for directory entries
static DirEntry* aDirEntries;

// number of directory entries in the buffer
static uint8_t nDirEntries;

static uint8_t nSelection;

/******************************************************************************/
/**
 * Return != 0 if the entry is a directory.
 */
static uint8_t __fastcall__ fileDlgEntryIsDir(DirEntry* pEntry)
{
    return !strcmp(pEntry->type, "dir");
}

/******************************************************************************/
/**
 * Compare function for qsort
 */
static int fileDlgCompareEntries(const void* a, const void* b)
{
    // arrow left must be the first entry
    if (((DirEntry*)a)->name[0] == 95)
        return 0;
    if (((DirEntry*)b)->name[0] == 95)
        return 1;

    if (fileDlgEntryIsDir((DirEntry*)a) && !fileDlgEntryIsDir((DirEntry*)b))
        return 0;
    if (fileDlgEntryIsDir((DirEntry*)b) && !fileDlgEntryIsDir((DirEntry*)a))
        return 1;

    return strcasecmp(((DirEntry*)a)->name,
                      ((DirEntry*)b)->name) > 0;
}

/******************************************************************************/
/**
 * Inspiration from http://de.wikipedia.org/wiki/Bottom-Up-Heapsort
 */
void fileDlgSort(void)
{
    DirEntry entry;
    uint8_t parent, child, root, n;
    n = nDirEntries;

    root = n >> 1;

    for (;;)
    {
        if (root)
        {
            parent = --root;
            entry = aDirEntries[root];
        }
        else if (--n)
        {
            entry = aDirEntries[n];
            aDirEntries[n] = aDirEntries[0];
            parent = 0;
        }
        else
            break;

        while ((child = (parent + 1) << 1) < n)
        {
            if (fileDlgCompareEntries(aDirEntries + (child - 1), aDirEntries + child))
                --child;

            aDirEntries[parent] = aDirEntries[child];
            parent = child;
        }

        if (child == n)
        {
            --child;
            if (fileDlgCompareEntries(aDirEntries + child, &entry))
            {
                aDirEntries[parent] = aDirEntries[child];
                aDirEntries[child] = entry;
                continue;
            }

            child = parent;
        }
        else
        {
            if (fileDlgCompareEntries(aDirEntries + parent, &entry))
            {
                aDirEntries[parent] = entry;
                continue;
            }

            child = (parent - 1) >> 1;
        }

        while (child != root)
        {
            parent = (child - 1) >> 1;
            if (fileDlgCompareEntries(aDirEntries + parent, &entry))
                break;

            aDirEntries[child] = aDirEntries[parent];
            child = parent;
        }

        aDirEntries[child] = entry;
    }
}

/******************************************************************************/
/**
 * Read the directory into the buffer and set the number of entries.
 */
static void fileDlgReadDir(void)
{
    DirEntry* pEntry;
    uint8_t c;
    uint8_t oldState;

    nDirEntries = 0;
    pEntry = aDirEntries;

    oldState = spritesOn(0);
    if (dirOpen(FILEDLG_LFN, nDriveNumber))
    {
        dirClose(FILEDLG_LFN);
        spritesOn(oldState);
        return;
    }

    // read entries, but leave two slots free for "<-/..", see below
    while ((!dirReadEntry(pEntry)) && (nDirEntries
            < FILEDLG_MAX_ENTRIES - 2))
    {
        if (pEntry->size > 9999)
            pEntry->size = 9999;

        // only accept supported file types
        if (strcmp(pEntry->name, "..") &&
            strcmp(pEntry->name, ".") &&
            strcmp(pEntry->name, strUp) &&
            strcmp(pEntry->type, "***"))
        {
            ++pEntry;
            ++nDirEntries;
        }

        c = (c == '+') ? c = '*' : c = '+';
        cputcxy(FILEDLG_X + FILEDLG_W - 2, FILEDLG_Y + 1, c);
    }
    cputcxy(FILEDLG_X + FILEDLG_W - 2, FILEDLG_Y + 1, ' ');

    dirClose(FILEDLG_LFN);

    // add "<-" (arrow left) for parent directory
    strcpy(pEntry->name, strUp);
    pEntry->size = 0;
    strcpy(pEntry->type, "dir");
    ++pEntry;
    // and ".."
    strcpy(pEntry->name, "..");
    pEntry->size = 0;
    strcpy(pEntry->type, "dir");
    ++pEntry;
    nDirEntries += 2;

    fileDlgSort();

    if (nDirEntries == FILEDLG_MAX_ENTRIES)
    {
        screenPrintSimpleDialog(apStrDirFull);
        refreshMainScreen();
        fileDlgPrintFrame();
    }

    spritesOn(oldState);
}


/******************************************************************************/
/**
 * Print/Update the file dialog of the headline
 */
static void __fastcall__ fileDlgHeadline(const char* pStrType)
{
    strcpy(utilStr, "Select ");
    strcat(utilStr, pStrType);
    strcat(utilStr, " file - drive ");
    utilAppendDecimal(nDriveNumber);
    utilAppendChar(' ');
    cputsxy(FILEDLG_X + 1, FILEDLG_Y + 1, utilStr);
}


/******************************************************************************/
/**
 * Print/Update the file dialog of the headline
 */
static void fileDlgPrintFrame(void)
{
    screenPrintBox(FILEDLG_X, FILEDLG_Y, FILEDLG_W, FILEDLG_H);
    screenPrintSepLine(FILEDLG_X, FILEDLG_X + FILEDLG_W - 1, FILEDLG_Y + 2);
    screenPrintSepLine(FILEDLG_X, FILEDLG_X + FILEDLG_W - 1, FILEDLG_Y + FILEDLG_H - 3);
    cputsxy(FILEDLG_X + 1, FILEDLG_Y + FILEDLG_H - 2, "Up/Down/0..9/F5/Stop/Enter");
}


/******************************************************************************/
/**
 */
static void __fastcall__ fileDlgPrintEntry(uint8_t nLine, uint8_t nEntry)
{
    DirEntry* pEntry;

    pEntry = aDirEntries + nEntry;

    gotoxy(FILEDLG_X + 1, FILEDLG_Y_ENTRIES + nLine);

    if (nEntry == nSelection)
        revers(1);

    // clear line
    cclear(FILEDLG_W - 2);

    // blocks
    utilStr[0] = 0;
    utilAppendDecimal(pEntry->size);
    gotox(FILEDLG_X + 5 - strlen(utilStr));
    cputs(utilStr);

    // name
    gotox(FILEDLG_X + 6);
    cputs(pEntry->name);

    // type
    gotox(FILEDLG_X + 23);
    cputs(pEntry->type);

    revers(0);
}


/******************************************************************************/
/**
 * Enter the relative directory given.
 *
 * return 1 for success, 0 for failure.
 */
void __fastcall__ fileDlgChangeDir(const char* pStrDir)
{
    uint8_t oldState;

    char strCmd[3 + FILENAME_MAX];

    strcpy(strCmd, "cd:");
    strcpy(strCmd + 3, pStrDir);

    oldState = spritesOn(0);
    cbm_open(15, nDriveNumber, 15, strCmd);
    cbm_close(15);
    spritesOn(oldState);
}


/******************************************************************************/
/**
 * Set the drive number to be used for the file browser.
 */
void fileDlgSetDriveNumber(uint8_t n)
{
    nDriveNumber = n;
}


/******************************************************************************/
/**
 * Set the drive number to be used for the file browser.
 */
uint8_t fileDlgGetDriveNumber(void)
{
    return nDriveNumber;
}


/******************************************************************************/
/**
 * Show a file open dialog. If the user selects a file, copy the name to
 * pStrName. The three letter file type in pStrType is shown in the
 * headline.
 *
 * return 1 if the user has selected a file, 0 if he canceled
 * the dialog.
 */
uint8_t __fastcall__ fileDlg(char* pStrName, const char* pStrType)
{
    uint8_t nTopLine;
    unsigned char n, nEntry, nOldSelection;
    unsigned char bRefresh, bReload;
    char key;
    uint8_t rv;
    DirEntry* pEntry;

    bufferHideROM();
    fileDlgPrintFrame();

    aDirEntries = BUFFER_DIR_ADDR;
    rv = 0;

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
            fileDlgHeadline(pStrType);
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
                    if (nTopLine > FILEDLG_N_ENTRIES)
                        nTopLine -= FILEDLG_N_ENTRIES;
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
                    nTopLine += FILEDLG_N_ENTRIES;
                    bRefresh = 1;
                }
            }
            break;

        case CH_ENTER:
            pEntry = aDirEntries + nSelection;
            if (fileDlgEntryIsDir(pEntry))
            {
                fileDlgChangeDir(pEntry->name);
                bReload = 1;
            }
            else
            {
                strcpy(pStrName, pEntry->name);
                rv = 1;
                goto end; // yeah!
            }
            break;

        case CH_STOP:
            goto end; // yeah!

        case CH_F5:
            bReload = 1;
            break;

        default:
            if (key >= '0' && key <= '9')
            {
                if (key >= '8')
                    nDriveNumber = key - '0';
                else
                    nDriveNumber = 10 + key - '0';

                fileDlgHeadline(pStrType);
                bReload = 1;
            }
        }
    }
end:
    bufferShowROM();
    return rv;
}
