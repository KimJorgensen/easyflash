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
#include <stdio.h>

#include "util.h"
#include "filedlg.h"
#include "screen.h"
#include "texts.h"
#include "easyprog.h"

// globally visible string buffer for functions used here
char utilStr[80];

// File name of last CRT image
char strFileName[FILENAME_MAX];

// points to utilRead function to be used to read bytes from file
int __fastcall__ (*utilRead)(void* buffer, unsigned int size);

// Number of current split file (0...)
static uint8_t nCurrentPart;

// ID of current split file
static uint16_t nCurrentFileId;


/******************************************************************************/
/* prototypes */
static uint8_t __fastcall__ utilOpenEasySplitFile(uint8_t nDrive,
                                                  const char* pStrFileName,
                                                  uint8_t nPart);


/******************************************************************************/
/**
 * Open the file for read access. Check if the file is compressed. If yes,
 * select utilReadExomizerFile as current input method. If not, select
 * utilReadSelectNormalFile. Select this file as current input.
 *
 * OPEN_FILE_OK, OPEN_FILE_ERR, OPEN_FILE_WRONG
 */
uint8_t __fastcall__ utilOpenFile(uint8_t nDrive, const char* pStrFileName)
{
    uint8_t rv;

    utilRead = utilReadNormalFile;

    // try to open it as EasySplit file
    rv = utilOpenEasySplitFile(nDrive, pStrFileName, 0);

    // return if it is opened or if it is a wrong EasySplit part
    if (rv != OPEN_FILE_ERR)
        return rv;

    // that's not an EasySplit file: try to open it as normal file
    if (cbm_open(UTIL_GLOBAL_READ_LFN, nDrive, CBM_READ, pStrFileName) ||
        cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
    {
        return OPEN_FILE_ERR;
    }

    return OPEN_FILE_OK;
}


/******************************************************************************/
/**
 * Try to open an EasySplit file. The header will be read here and the file
 * position will be directly behind the header in case of success.
 *
 * return:
 * OPEN_FILE_OK     for OK
 * OPEN_FILE_ERR    for an error or if it is not an EasySplit file
 * OPEN_FILE_WRONG  if it is an EasySplit file, but the wrong part
 */
static uint8_t __fastcall__ utilOpenEasySplitFile(uint8_t nDrive,
                                                  const char* pStrFileName,
                                                  uint8_t nPart)
{
    const char strEasySplitSignature[8] = { 0x65, 0x61, 0x73, 0x79, 0x73, 0x70, 0x6c, 0x74 };
    const char* apStr[3];
    EasySplitHeader header;

    if (cbm_open(UTIL_GLOBAL_READ_LFN, nDrive, CBM_READ, pStrFileName))
        return OPEN_FILE_ERR;

    if (cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
        goto closeErr;

    if (utilReadNormalFile(&header, sizeof(header)) != sizeof(header))
        goto closeErr;

    // give up if we don't find the magic string
    if (memcmp(strEasySplitSignature, header.magic, sizeof(header.magic)))
        goto closeErr;

    if (nPart != header.part)
    {
        strcpy(utilStr, "This is not part ");
        utilAppendHex2(nPart + 1);
        utilAppendChar('.');
        apStr[0] = utilStr;
        apStr[1] = "Select the right part.";
        apStr[2] = NULL;

        screenPrintDialog(apStr, BUTTON_ENTER);
        utilCloseFile();
        return OPEN_FILE_WRONG;
    }

    if (nPart == 0)
    {
        nUtilExoBytesRemaining = *(uint32_t*)(header.len);

        // the read function expects the two's complement - 1
        nUtilExoBytesRemaining = -nUtilExoBytesRemaining - 1;
        utilRead = utilReadEasySplitFile;
        utilInitDecruncher();
        nCurrentFileId = *(uint16_t*)(header.id);
    }
    else
    {
        if (nCurrentFileId != *(uint16_t*)(header.id))
        {
            screenPrintDialog(apStrDifferentFile, BUTTON_ENTER);
            utilCloseFile();
            return OPEN_FILE_WRONG;
        }
    }

    nCurrentPart = nPart;
    return OPEN_FILE_OK;

closeErr:
    if (nPart)
        screenPrintSimpleDialog(apStrFileNoEasySplit);

    utilCloseFile();
    return OPEN_FILE_ERR;
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
 * Return 1 if a good file has been selected, 0 otherwise.
 */
uint8_t utilAskForNextFile(void)
{
    static char str[3];
    uint8_t     ret;

    utilCloseFile();

    ++nCurrentPart;
    utilStr[0] = '\0';
    utilAppendHex2(nCurrentPart + 1);
    // Must copy this, because fileDlg uses utilStr
    strcpy(str, utilStr);

    do
    {
        do
        {
            refreshMainScreen();
            ret = fileDlg(strFileName, str);

            if (!ret)
            {
                ret = screenPrintTwoLinesDialog("If you really want",
                                                "to abort, press <Stop>.");
                if (ret == BUTTON_STOP)
                    return 0;
            }
        }
        while (!ret);

        ret = utilOpenEasySplitFile(fileDlgGetDriveNumber(), strFileName,
                                    nCurrentPart);
    }
    while (ret != OPEN_FILE_OK);

    refreshMainScreen();
    return 1;
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

