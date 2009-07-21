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

/******************************************************************************/
/* Static variables */

/* static to save some function call overhead */
static uint8_t  nBank;
static uint16_t nAddress;
static uint16_t nSize;
static BankHeader bankHeader;

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
 * Write a Normal 8K image from the given file to flash.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeCrtImageNormal8k(uint8_t lfn)
{
    uint8_t rv;

    rv = readNextHeader(lfn);

    if (rv == CART_RV_OK)
    {

        if ((nSize > 0x2000) || (nAddress != (uint16_t) ROM0_BASE) ||
            (nBank != 0))
        {
            screenPrintSimpleDialog(apStrUnsupportedCRTData);
            return CART_RV_ERR;
        }

        // write the startup code to bank 0, always write 256 bytes
        if (!flashWriteBlock(0, 1, 0x1F00, startUpEnd - 0x100))
        {
            return writeCRTError();
        }

        // real CRT to bank 1, because we wrote the startup code to bank 0
        if (!flashWriteBlockFromFile(1, 0, nSize, lfn))
        {
            return writeCRTError();
        }
    }
    else if (rv == CART_RV_ERR)
    {
        screenPrintSimpleDialog(apStrChipReadError);
        return CART_RV_ERR;
    }

    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write a crt image from the given file to flash.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeCrtImage(uint8_t lfn)
{
    setStatus("Reading CRT header");
    if (!readCartHeader(lfn))
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        return CART_RV_ERR;
    }

    switch (internalCartType)
    {
    case INTERNAL_CART_TYPE_NORMAL_8K:
        return writeCrtImageNormal8k(lfn);
        break;

    default:
        screenPrintSimpleDialog(apStrUnsupportedCRTType);
        break;
    }

    return CART_RV_ERR;
}

#if 0
    do
    {
        setStatus("Reading header from file");
        rv = readNextBankHeader(&bankHeader, lfn);

        if (rv == CART_RV_OK)
        {
            nBank = bankHeader.bank[1];
            nAddress = 256 * bankHeader.loadAddr[0] + bankHeader.loadAddr[1];
            nSize = 256 * bankHeader.romLen[0] + bankHeader.romLen[1];

            if ((nAddress == (uint16_t) ROM0_BASE) && (nSize <= 0x4000))
            {
                if (nSize > 0x2000)
                {
                    flashWriteBlockFromFile(nBank, 0, 0x2000, lfn);
                    flashWriteBlockFromFile(nBank, 1, nSize - 0x2000, lfn);
                }
                else
                {
                    flashWriteBlockFromFile(nBank, 0, nSize, lfn);
                }
            }
            else if (((nAddress == (uint16_t) ROM1_BASE) || (nAddress
                    == (uint16_t) ROM1_BASE_ULTIMAX)) && (nSize <= 0x2000))
            {
                flashWriteBlockFromFile(nBank, 1, nSize, lfn);
            }
            else
            {
                // todo: error message
                gotoxy(0, 0);
                cprintf("Illegal CHIP address or size (%p, %p)", nAddress, nSize);
                for (;;)
                    ;
            }
        }
        else if (rv == CART_RV_ERR)
        {
            screenPrintSimpleDialog(apStrChipReadError);
            return CART_RV_ERR;
        }
    } while (rv == CART_RV_OK);

    setStatus("OK");
    return CART_RV_OK;
}
#endif


/******************************************************************************/
/**
 * Write and/or verify an CRT image file to the flash.
 *
 */
void checkWriteImage(void)
{
    const char *pStrInput;
    char strFileName[FILENAME_MAX];
    uint8_t lfn, rv;

    pStrInput = screenReadInput("Write CRT to flash", "Enter file name");

    refreshMainScreen();

    if (!pStrInput)
        return;

    strcpy(strFileName, pStrInput);

    setStatus("Checking file");

    lfn = 2;
    rv = cbm_open(lfn, 8, CBM_READ, strFileName);

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
