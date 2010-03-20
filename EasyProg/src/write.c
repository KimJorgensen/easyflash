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

#include <conio.h>
#include <string.h>
#include <time.h>

#include "buffer.h"
#include "cart.h"
#include "screen.h"
#include "texts.h"
#include "cart.h"
#include "easyprog.h"
#include "flash.h"
#include "startupbin.h"
#include "write.h"
#include "filedlg.h"
#include "sprites.h"
#include "progress.h"
#include "util.h"

/******************************************************************************/
/* Static variables */

/* static to save some function call overhead */
static uint8_t  nBank;
static uint16_t nAddress;
static uint16_t nSize;
static BankHeader bankHeader;

/******************************************************************************/
/**
 * Print a status line, read the next bank header from the currently active
 * input and calculate nBank, nAddress and nSize.
 *
 * return CART_RV_OK, CART_RV_ERR or CART_RV_EOF
 */
static uint8_t readNextHeader()
{
    uint8_t rv;

    setStatus("Reading header from file");
    rv = readNextBankHeader(&bankHeader);

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
    uint8_t  nConfig;
    uint8_t* pBuffer;

    // most CRT types are put on bank 1
    *pBankOffset = 1;

    switch (internalCartType)
    {
    case INTERNAL_CART_TYPE_NORMAL_8K:
        nConfig = EASYFLASH_IO_8K;
        break;

    case INTERNAL_CART_TYPE_NORMAL_16K:
        nConfig = EASYFLASH_IO_16K;
        break;

    case INTERNAL_CART_TYPE_ULTIMAX:
        nConfig = EASYFLASH_IO_ULTIMAX;
        break;

    case INTERNAL_CART_TYPE_OCEAN1:
        nConfig = EASYFLASH_IO_16K;
        *pBankOffset = 0;
        break;

    case INTERNAL_CART_TYPE_EASYFLASH:
        *pBankOffset = 0;
        return CART_RV_OK;

    case INTERNAL_CART_TYPE_EASYFLASH_XBANK:
        nConfig = nXbankConfig;
        break;

    default:
        screenPrintSimpleDialog(apStrUnsupportedCRTType);
        return CART_RV_ERR;
    }

    pBuffer = BUFFER_WRITE_ADDR;

    // btw: the buffer must always be 256 bytes long
    // !!! keep this crap in sync with startup.s - especially the code size !!!
    // copy the startup code to the buffer and patch the start bank and config
    memcpy(pBuffer, startUpStart, 0x100);

    // the 1st byte of this code is the start bank to be used - patch it
    pBuffer[0] = *pBankOffset;

    // the 2nd byte of this code is the memory config to be used - patch it
    pBuffer[1] = nConfig | EASYFLASH_IO_BIT_LED;

    // write the startup code to bank 0, always write 2 * 256 bytes
    if (!flashWriteBlock(0, 1, 0x1e00, pBuffer) ||
        !flashWriteBlock(0, 1, 0x1f00, startUpStart + 0x100))
    {
        return writeCRTError();
    }


    // write the sprites to 00:1:1800
    // keep this in sync with sprites.s
    if (!flashWriteBlock(0, 1, 0x1800, pSprites) ||
        !flashWriteBlock(0, 1, 0x1900, pSprites + 0x100))
        return writeCRTError();

    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write a cartridge image from the currently active input (file) to flash.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeCrtImage(void)
{
    uint8_t rv;
    uint8_t nBankOffset;

    setStatus("Reading CRT header");
    if (!readCartHeader())
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        return CART_RV_ERR;
    }

    // this will show the cartridge type from the header
    refreshMainScreen();

    if (writeStartUpCode(&nBankOffset) != CART_RV_OK)
        return CART_RV_ERR;

    do
    {
        rv = readNextHeader();
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
                    if (!flashWriteBlockFromFile(nBank, 0, 0x2000) ||
                        !flashWriteBlockFromFile(nBank, 1, nSize - 0x2000))
                    {
                        return CART_RV_ERR;
                    }
                }
                else
                {
                    if (!flashWriteBlockFromFile(nBank, 0, nSize))
                        return CART_RV_ERR;
                }
            }
            else if (((nAddress == (uint16_t) ROM1_BASE) ||
                      (nAddress == (uint16_t) ROM1_BASE_ULTIMAX)) &&
                     (nSize <= 0x2000))
            {
                if (!flashWriteBlockFromFile(nBank, 1, nSize))
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
 * Write a BIN image from the given file to flash, either LOROM or HIROM.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeBinImage(uint8_t nChip)
{
    uint8_t  nBank;
    uint16_t nOffset;
    int      nBytes;
    uint8_t* pBuffer;
    char strStatus[41];

    // this will show the cartridge type from the header
    refreshMainScreen();

    pBuffer = BUFFER_WRITE_ADDR;
    nOffset = 0;
    nBank = 0;
    do
    {
        strcpy(strStatus, "Reading from file");
        setStatus(strStatus);

        nBytes = utilRead(pBuffer, 0x100);

        if (nBytes >= 0)
        {
            // the last block may be smaller than 265 bytes, then we write padding
            if (!flashWriteBlock(nBank, nChip, nOffset, pBuffer))
                return 0;

            if (!flashVerifyBlock(nBank, nChip, nOffset, pBuffer))
                return 0;

            nOffset += 0x100;
            if (nOffset == 0x2000)
            {
                nOffset = 0;
                ++nBank;
            }
        }
        else
            break;  // shorter code...
    }
    while (nBytes == 0x100);

    if (nOffset || nBank)
        return CART_RV_OK;
    else
        return CART_RV_ERR;
}


/******************************************************************************/
/**
 * Write an image file to the flash.
 *
 * imageType must be one of IMAGE_TYPE_CRT, IMAGE_TYPE_LOROM, IMAGE_TYPE_HIROM.
 */
static void checkWriteImage(uint8_t imageType)
{
    unsigned t;
    uint8_t  rv;
    uint8_t  oldState;

    checkFlashType();

    do
    {
        rv = fileDlg(strFileName, imageType == IMAGE_TYPE_CRT ? "CRT" : "BIN");
        if (!rv)
            return;

        oldState = spritesOn(0);
        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        spritesOn(oldState);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    if (screenAskEraseDialog() != BUTTON_ENTER)
    {
    	utilCloseFile();
        return;
    }

    refreshMainScreen();

    setStatus("Checking file");

    // make sure the right areas of the chip are erased
    progressInit();

    t = clock();
    oldState = spritesOn(0);

    if (imageType == IMAGE_TYPE_CRT)
        rv = writeCrtImage();
    else
        rv = writeBinImage(imageType == IMAGE_TYPE_HIROM);
    utilCloseFile();

    spritesOn(oldState);
    t = clock() - t;

    if (rv == CART_RV_OK)
        screenPrintSimpleDialog(apStrWriteComplete);

#if 0
    {
        strcpy(utilStr, "time: ");
        utilAppendDecimal(t / CLK_TCK);
        utilAppendChar('.');
        utilAppendDecimal((t % CLK_TCK) / (CLK_TCK / 10));
        cputsxy(0, 0, utilStr);
    }
    for (;;);
#endif
}


/******************************************************************************/
/**
 * Write a CRT image file to the flash.
 */
void checkWriteCRTImage(void)
{
    checkWriteImage(IMAGE_TYPE_CRT);
}


/******************************************************************************/
/**
 * Write a BIN image file to the LOROM flash.
 */
void checkWriteLOROMImage(void)
{
    checkWriteImage(IMAGE_TYPE_LOROM);
}


/******************************************************************************/
/**
 * Write a BIN image file to the HIROM flash.
 */
void checkWriteHIROMImage(void)
{
    checkWriteImage(IMAGE_TYPE_HIROM);
}
