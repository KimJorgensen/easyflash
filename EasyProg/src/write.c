/*
 * EasyProg - write.c - Write cartridge image to flash
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
#include <string.h>
#include <cbm.h>

#include "cart.h"
#include "screen.h"
#include "texts.h"
#include "cart.h"
#include "easyprog.h"
#include "flash.h"
#include "startupbin.h"
#include "write.h"
#include "filedlg.h"

/******************************************************************************/
/* Static variables */

/* static to save some function call overhead */
static uint8_t  nBank;
static uint16_t nAddress;
static uint16_t nSize;
static BankHeader bankHeader;

// static because my heap doesn't work yet
// The buffer must always be 256 bytes long
static uint8_t startUpBuffer[256];


/******************************************************************************/
/**
 * Print a status line, read the next bank header and calculate nBank,
 * nAddress and nSize.
 *
 * return CART_RV_OK, CART_RV_ERR or CART_RV_EOF
 */
static uint8_t readNextHeader(uint8_t lfn)
{
    uint8_t rv;

    setStatus("Reading header from file");
    rv = readNextBankHeader(&bankHeader, lfn);

    nBank = bankHeader.bank[1];
    nAddress = 256 * bankHeader.loadAddr[0] + bankHeader.loadAddr[1];
    nSize = 256 * bankHeader.romLen[0] + bankHeader.romLen[1];

    return rv;
}


/******************************************************************************/
/**
 * Show an error dialog because writing a CRT image failed.
 * Return CART_RV_ERR
 */
static uint8_t writeCRTError(void)
{
    screenPrintSimpleDialog(apStrWriteCRTFailed);
    return CART_RV_ERR;
}


/******************************************************************************/
/**
 * Write the startup code to 00:1:xxxx. Patch it to use the right memory
 * configuration for the present cartridge type.
 *
 * Put the bank offset to be used in *pBankOffset. This offset must be added
 * to all banks of this cartridge. This is done to keep space on bank 00:1
 * for the start up code.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t __fastcall__ writeStartUpCode(uint8_t* pBankOffset)
{
    uint8_t nConfig;
    uint8_t nCodeSize;
    unsigned char* pBase;

    switch (internalCartType)
    {
    case INTERNAL_CART_TYPE_NORMAL_8K:
        nConfig = EASYFLASH_IO_8K;
        *pBankOffset = 1;
        break;

    case INTERNAL_CART_TYPE_NORMAL_16K:
        nConfig = EASYFLASH_IO_16K;
        *pBankOffset = 1;
        break;

    case INTERNAL_CART_TYPE_ULTIMAX:
        nConfig = EASYFLASH_IO_ULTIMAX;
        *pBankOffset = 1;
        break;

    case INTERNAL_CART_TYPE_OCEAN1:
        nConfig = EASYFLASH_IO_16K;
        *pBankOffset = 0;
        break;

    case INTERNAL_CART_TYPE_EASYFLASH:
        // nothing to do
        return CART_RV_OK;

    default:
        screenPrintSimpleDialog(apStrUnsupportedCRTType);
        return CART_RV_ERR;
    }

    // btw: the buffer must always be 256 bytes long
    memset(startUpBuffer, 0xff, 0x100);

    // copy the startup code to the end of the buffer
    nCodeSize = startUpEnd - startUpStart;
    pBase = startUpBuffer + 256 - nCodeSize;
    memcpy(pBase, startUpStart, nCodeSize);

    // the 1st byte of this code is the start bank to be used - patch it
    pBase[0] = *pBankOffset;

    // the 2nd byte of this code is the memory config to be used - patch it
    pBase[1] = nConfig | EASYFLASH_IO_BIT_LED;

    // write the startup code to bank 0, always write 256 bytes
    if (!flashWriteBlock(0, 1, 0x1F00, startUpBuffer))
        return writeCRTError();

    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write a cartridge image from the given file to flash.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeCrtImage(uint8_t lfn)
{
    uint8_t rv;
    uint8_t nBankOffset;

    setStatus("Reading CRT header");
    if (!readCartHeader(lfn))
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        return CART_RV_ERR;
    }

    if (writeStartUpCode(&nBankOffset) != CART_RV_OK)
        return CART_RV_ERR;

    do
    {
        rv = readNextHeader(lfn);
        if (rv == CART_RV_ERR)
        {
            screenPrintSimpleDialog(apStrChipReadError);
            return CART_RV_ERR;
        }

        if (rv == CART_RV_OK)
        {
            nBank += nBankOffset;

            if ((nAddress == (uint16_t) ROM0_BASE) && (nSize <= 0x4000))
            {
                if (nSize > 0x2000)
                {
                    if (!flashWriteBlockFromFile(nBank, 0, 0x2000, lfn) ||
                        !flashWriteBlockFromFile(nBank, 1, nSize - 0x2000, lfn))
                    {
                        return CART_RV_ERR;
                    }
                }
                else
                {
                    if (!flashWriteBlockFromFile(nBank, 0, nSize, lfn))
                        return CART_RV_ERR;
                }
            }
            else if (((nAddress == (uint16_t) ROM1_BASE) ||
                      (nAddress == (uint16_t) ROM1_BASE_ULTIMAX)) &&
                     (nSize <= 0x2000))
            {
                if (!flashWriteBlockFromFile(nBank, 1, nSize, lfn))
                    return CART_RV_ERR;
            }
            else
            {
                screenPrintSimpleDialog(apStrUnsupportedCRTData);
                return CART_RV_ERR;
            }
        }

        // rv == CART_RV_EOF is the normal way to leave this loop
    }
    while (rv == CART_RV_OK);

    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write and/or verify an CRT image file to the flash.
 *
 */
void checkWriteImage(void)
{
    char strFileName[FILENAME_MAX];
    uint8_t lfn, rv;

    //pStrInput = screenReadInput("Write CRT to flash", "Enter file name");
    if (!fileDlg(strFileName))
        return;

    if (screenAskEraseDialog() != BUTTON_ENTER)
        return;

    refreshMainScreen();

    setStatus("Checking file");

    lfn = 2;
    rv = cbm_open(lfn, fileDlgGetDriveNumber(), CBM_READ, strFileName);

    if (rv)
    {
        screenPrintSimpleDialog(apStrFileOpenError);
        return;
    }

    if (writeCrtImage(lfn) == CART_RV_OK)
        setStatus("OK");
    else
        setStatus("Error");

    cbm_close(lfn);
}
