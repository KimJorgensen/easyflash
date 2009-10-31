/*
 * EasyProg - util.c
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

#include <buffer.h>
#include <cbm.h>
#include <string.h>
#include <conio.h>

#include "util.h"

// globally visible string buffer for functions used here
char utilStr[80];

// points to utilRead function to be used to read bytes from file
int __fastcall__ (*utilRead)(void* buffer, unsigned int size);


/******************************************************************************/
/**
 * Open the file for read access. Check if the file is compressed. If yes,
 * select utilReadExomizerFile as current input method. If not, select
 * utilReadSelectNormalFile. Select this file as current input.
 *
 * return 0 if okay, 1 for error
 */
uint8_t __fastcall__ utilOpenFile(uint8_t nDrive, const char* pStrFileName)
{
    const char strEasySplitSignature[8] = { 0x65, 0x61, 0x73, 0x79, 0x73, 0x70, 0x6c, 0x74 };
    char buffer[sizeof(strEasySplitSignature)];

    if (cbm_open(UTIL_GLOBAL_READ_LFN, nDrive, CBM_READ, pStrFileName) ||
        cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
    {
        return 1;
    }

    utilRead = utilReadNormalFile;

    // Check if it is compressed (EASYSPLIT)
    if (utilReadNormalFile(buffer, sizeof(buffer)) != sizeof(buffer) ||
        memcmp(buffer, strEasySplitSignature, sizeof(buffer)))
    {
        // No EasySplit file, open it again to rewind
        utilCloseFile();

        if (cbm_open(UTIL_GLOBAL_READ_LFN, nDrive, CBM_READ, pStrFileName) ||
            cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
        {
            return 1;
        }
    }
    else
    {
        // an EasySplit file => read file size
        if ( utilReadNormalFile(&nUtilExoBytesRemaining, sizeof(nUtilExoBytesRemaining)) !=
             sizeof(nUtilExoBytesRemaining) )
        {
            return 1;
        }

        // the read function expects the two's complement - 1
        nUtilExoBytesRemaining = -nUtilExoBytesRemaining - 1;
        utilRead = utilReadEasySplitFile;
        utilInitDecruncher();

        gotoxy(0, 0);
        cprintf("Easysplit, %ld bytes", nUtilExoBytesRemaining);
        //for(;;);
    }

    return 0;
}


/******************************************************************************/
/**
 *
 */
void utilCloseFile(void)
{
    cbm_k_clrch();
    cbm_close(UTIL_GLOBAL_READ_LFN);
}


/******************************************************************************/
/**
 *
 */
void __fastcall__ utilAppendFlashAddr(uint8_t nBank,
                                      uint8_t nChip,
                                      uint16_t nOffset)
{
    utilAppendHex2(nBank);
    utilAppendChar(':');
    utilAppendHex1(nChip);
    utilAppendChar(':');
    utilAppendHex2(nOffset >> 8);
    utilAppendHex2(nOffset);
}


/******************************************************************************/
/**
 *
 */
void __fastcall__ utilAppendDecimal(uint16_t n)
{
    uint8_t aNum[5];
    int8_t  i;

    // write number backwards
    if (n)
    {
        i = 0;
        while (n)
        {
            aNum[i++] = n % 10;
            n /= 10;
        }

        while (--i >= 0)
        {
            // slow!
            utilAppendChar('0' + aNum[i]);
        }
    }
    else
        utilAppendChar('0');
}

