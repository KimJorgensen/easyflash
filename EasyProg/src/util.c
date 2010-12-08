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
#include "uload.h"


// globally visible string buffer for functions used here
char utilStr[80];

// points to utilRead function to be used to read bytes from file
int __fastcall__ (*utilRead)(void* buffer, unsigned int size);

// points to getCrunchedByte function for the decruncher
void (*getCrunchedByte)(void);

extern void getCrunchedByteKernal(void);
extern void uloadGetCrunchedByte(void);

/******************************************************************************/
/** Local data: Put here to reduce code size */

// This header is read by utilCheckFileHeader which is called by utilOpenFile.
// It can be used to identify the file type.
static union
{
    char            data[16];
    EasySplitHeader easySplitHeader;
} m_uFileHeader;

// Number of current split file (0...)
static uint8_t nCurrentPart;

// ID of current split file
static uint16_t nCurrentFileId;

// Set by utilOpenInternal
static uint8_t bHaveULoad;

static const char aEasySplitSignature[8] =
{
        0x65, 0x61, 0x73, 0x79, 0x73, 0x70, 0x6c, 0x74
};

/******************************************************************************/
/* prototypes */
static uint8_t utilCheckFileHeader(void);
static uint8_t __fastcall__ utilOpenEasySplitFile(uint8_t nPart);
static uint8_t utilOpenULoadFile(void);
static void utilComplainWrongPart(uint8_t nPart);
static uint8_t utilOpenInternal(void);


/******************************************************************************/
/**
 * Open the file for read access. Check if the file is compressed and select
 * the right read functions.
 *
 * nPart is the part number for split files. If this is 0 the file may be not
 * split or it may be the first part of a split file. Otherwise it must be the
 * right split file > 0.
 *
 * OPEN_FILE_OK, OPEN_FILE_ERR, OPEN_FILE_WRONG
 */
uint8_t utilOpenFile(uint8_t nPart)
{
    uint8_t rv, type;

    // this reads m_uFileHeader and returns the type detected
    type = utilCheckFileHeader();
    if (type == OPEN_FILE_ERR)
        return type;

    if (nPart == 0)
    {
        // it may be a split file part 1 or a plain file
        if (type == OPEN_FILE_TYPE_ESPLIT)
        {
            return utilOpenEasySplitFile(nPart);
        }
        else
        {
            // plain file
            return utilOpenInternal();
        }
    }
    else
    {
         if (type != OPEN_FILE_TYPE_ESPLIT)
         {
             screenPrintSimpleDialog(apStrFileNoEasySplit);
             return OPEN_FILE_WRONG;
         }
         return utilOpenEasySplitFile(nPart);
    }

    return OPEN_FILE_OK;
}


/******************************************************************************/
/**
 *
 */
void utilCloseFile(void)
{
    int val;

    if (!bHaveULoad)
    {
        cbm_k_clrch();
        cbm_close(UTIL_GLOBAL_READ_LFN);
    }
    else
    {
        uloadExit();
    }
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
        	screenBing();
            refreshMainScreen();
            ret = fileDlg(str);

            if (!ret)
            {
                ret = screenPrintTwoLinesDialog("If you really want",
                                                "to abort, press <Stop>.");
                if (ret == BUTTON_STOP)
                    return 0;
            }
        }
        while (!ret);

        ret = utilOpenFile(nCurrentPart);
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


/******************************************************************************/
/**
 *
 * Open a file, take the name from g_strFileName. The directory is parsed
 * here to find out track and sector.
 *
 * return: OPEN_FILE_OK, OPEN_FILE_ERR
 */
static uint8_t utilOpenULoadFile(void)
{
    *(uint8_t*)0xba = g_nDrive;

    if (uloadOpenFile(g_strFileName))
        return OPEN_FILE_OK;
    else
        return OPEN_FILE_ERR;
}



/******************************************************************************/
/**
 * Open an EasySplit file. Only called from utilOpenFile! The caller checked
 * already that it has the right file type and filled m_uFileHeader.
 * The file will be re-opened here, possibly using a speeder. Therefore we
 * have to skip the header again.
 *
 * return:
 *      OPEN_FILE_OK     for OK
 *      OPEN_FILE_ERR    for an error or if it is not an EasySplit file
 *      OPEN_FILE_WRONG  if it is an EasySplit file, but the wrong part
 */
static uint8_t __fastcall__ utilOpenEasySplitFile(uint8_t nPart)
{
    uint8_t i;
    uint8_t rv;

    if (nPart != m_uFileHeader.easySplitHeader.part)
    {
        utilComplainWrongPart(nPart);
        return OPEN_FILE_WRONG;
    }
    if ((nPart != 0) &&
        (nCurrentFileId != *(uint16_t*)(m_uFileHeader.easySplitHeader.id)))
    {
        screenPrintDialog(apStrDifferentFile, BUTTON_ENTER);
        return OPEN_FILE_WRONG;
    }

    rv = utilOpenInternal();
    if (rv != OPEN_FILE_OK)
        return rv;

    // correct the read function pointer
    utilRead = utilReadEasySplitFile;
    // skip the header again
    for (i = 0; i < sizeof(EasySplitHeader); ++i)
        getCrunchedByte();

    if (nPart == 0)
    {
        nUtilExoBytesRemaining =
                *(uint32_t*)(m_uFileHeader.easySplitHeader.len);

        // the read function expects the two's complement - 1
        nUtilExoBytesRemaining = -nUtilExoBytesRemaining - 1;
        utilInitDecruncher();
        nCurrentFileId = *(uint16_t*)(m_uFileHeader.easySplitHeader.id);
    }

    nCurrentPart = nPart;
    return OPEN_FILE_OK;
}


/******************************************************************************/
/**
 * return:
 *          OPEN_FILE_ERR    file couldn't be opened
 *          OPEN_FILE_WRONG  unknown file type
 *          OPEN_FILE_TYPE_  file type detected
 */
static uint8_t utilCheckFileHeader(void)
{
    uint8_t len;

    if (cbm_open(UTIL_GLOBAL_READ_LFN, g_nDrive, CBM_READ, g_strFileName))
        return OPEN_FILE_ERR;

    if (cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
    {
        cbm_close(UTIL_GLOBAL_READ_LFN);
        return OPEN_FILE_ERR;
    }

    len = utilKernalRead(&m_uFileHeader, sizeof(m_uFileHeader));
    bHaveULoad = 0;
    utilCloseFile();

    if (len != sizeof(m_uFileHeader))
        return OPEN_FILE_WRONG;

    if (memcmp(m_uFileHeader.easySplitHeader.magic,
               aEasySplitSignature, sizeof(aEasySplitSignature)) == 0)
        return OPEN_FILE_TYPE_ESPLIT;

    return OPEN_FILE_WRONG;
}


/******************************************************************************/
/**
 */
static void utilComplainWrongPart(uint8_t nPart)
{
    const char* apStr[3];

    strcpy(utilStr, "This is not part ");
    utilAppendHex2(nPart + 1);
    utilAppendChar('.');
    apStr[0] = utilStr;
    apStr[1] = "Select the right part.";
    apStr[2] = NULL;

    screenPrintDialog(apStr, BUTTON_ENTER);
}


/******************************************************************************/
/**
 * The file has been checked already, it has the right type and the right part,
 * now we can really open it with the fast loader if possible and without if
 * not.
 */
static uint8_t utilOpenInternal(void)
{
    uint8_t rv;

    if (!bFastLoaderEnabled)
        bHaveULoad = 0;
    else
        bHaveULoad = uloadInit();

    if (bHaveULoad)
    {
        if (utilOpenULoadFile() == OPEN_FILE_ERR)
            return OPEN_FILE_ERR;

        utilRead        = uloadRead;
        getCrunchedByte = uloadGetCrunchedByte;
    }
    else
    {
        // that's not an EasySplit file: try to open it as normal file
        if (cbm_open(UTIL_GLOBAL_READ_LFN, g_nDrive, CBM_READ, g_strFileName))
            return OPEN_FILE_ERR;

        if (cbm_k_chkin(UTIL_GLOBAL_READ_LFN))
        {
            cbm_close(UTIL_GLOBAL_READ_LFN);
            return OPEN_FILE_ERR;
        }

        utilRead        = utilKernalRead;
        getCrunchedByte = getCrunchedByteKernal;
    }
    return OPEN_FILE_OK;
}
