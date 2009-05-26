/*
 * EasyProg - easyprog.c - The main module
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
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <cbm.h>

#define FILEDLG_ENTRIES 256
#define FILEDLG_LFN     72

/******************************************************************************/

// A table with strings for all directory entry types
static const char* apStrEntryType[] =
{
	"DEL", "SEQ", "PRG", "USR", "REL", "-5-", "DIR", "-7-", "VRP"
};

/******************************************************************************/
/** Local data: Put here to reduce code size */

// buffer for directory entries
static struct cbm_dirent* pDirEntries;

// number of directory entries in the buffer
static uint16_t nDirEntries;


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

	pEntry = pDirEntries;
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
	nDirEntries = pEntry - pDirEntries;

  	cbm_closedir(FILEDLG_LFN);

	qsort(pDirEntries, nDirEntries, sizeof(pDirEntries[0]),
          fileDlgCompareEntries);
}

/******************************************************************************/
/**
 * Initialize the screen. Set up colors and clear it.
 */
void fileDlg(void)
{
    uint16_t i;
	struct cbm_dirent* pEntry;

	pDirEntries = malloc(FILEDLG_ENTRIES * sizeof(struct cbm_dirent));
	if (!pDirEntries)
	{
		cputsxy(0, 0, "Out of memory");
		for (;;);
	}

	fileDlgReadDir();

	gotoxy(0, 0);
	pEntry = pDirEntries;
	for (i = nDirEntries - 1; i; --i)
    {
		cprintf("%4d %-16s %s\r\n", pEntry->size, pEntry->name, apStrEntryType[pEntry->type]);
		++pEntry;
    }

	free(pDirEntries);
	for (;;);
}
