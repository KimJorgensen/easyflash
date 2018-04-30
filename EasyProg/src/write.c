/*
 * EasyProg - write.c - Write cartridge image to flash
 *
 * EasyProg version 1.8.0, April 2018, are
 * Copyright (c) 2018 Kim Jorgensen, are derived from EasyProg 1.7.1,
 * and are distributed according to the same disclaimer and license as
 * EasyProg 1.7.1
 *
 * EasyProg versions 1.2 September 2009, through 1.7.1, September 2013, are
 * Copyright (c) 2009-2013 Thomas Giesel
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
#include <stdlib.h>

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
#include "slots.h"
#include "progress.h"
#include "timer.h"
#include "util.h"
#include "eload.h"
#include "eapiglue.h"

/******************************************************************************/
/* local macros for readability */

#define EP_INTERLEAVED      1
#define EP_NON_INTERLEAVED  0

#define EF3_AR_BANK     0x10
#define EF3_SS5_BANK    0x20
#define EF3_FC3_BANK    0x28

/******************************************************************************/
/* Static variables */

/* static to save some function call overhead */
static uint8_t  m_nBank;
static uint16_t m_nAddress;
static uint16_t m_nSize;
static BankHeader bankHeader;
static uint8_t m_bFileUSB;

/******************************************************************************/
/**
 * Print a status line, read the next bank header from the currently active
 * input and calculate m_nBank, m_nAddress and m_nSize.
 *
 * return CART_RV_OK, CART_RV_ERR or CART_RV_EOF
 */
static uint8_t readNextHeader()
{
    uint8_t rv;

    rv = readNextBankHeader(&bankHeader);

    m_nBank = bankHeader.bank[1] & FLASH_BANK_MASK;

    m_nAddress = 256 * bankHeader.loadAddr[0] + bankHeader.loadAddr[1];
    m_nSize = 256 * bankHeader.romLen[0] + bankHeader.romLen[1];

    return rv;
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
    EasyFlashAddr addr;
    uint8_t  nConfig;

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
        return CART_RV_OK; // nothing to do

    case INTERNAL_CART_TYPE_EASYFLASH_XBANK:
        nConfig = nXbankConfig;
        break;

    default:
        screenPrintSimpleDialog(apStrUnsupportedCRTType);
        goto err;
    }

    // !!! keep this crap in sync with startup.s - especially the code size !!!
    // copy the startup code to the buffer and patch the start bank and config
    memcpy(BLOCK_BUFFER, startUpStart, 0x100);

    // the 1st byte of this code is the start bank to be used - patch it
    BLOCK_BUFFER[0] = *pBankOffset;

    // the 2nd byte of this code is the memory config to be used - patch it
    BLOCK_BUFFER[1] = nConfig | EASYFLASH_IO_BIT_LED;

    // write the startup code to bank 0, always write 2 * 256 bytes
    addr.nSlot = g_nSelectedSlot;
    addr.nBank = 0;
    addr.nChip = 1;
    addr.nOffset = 0x1e00;
    if (!flashWriteBlock(&addr))
        goto err;

    memcpy(BLOCK_BUFFER, startUpStart + 0x100, 0x100);
    addr.nOffset = 0x1f00;
    if (!flashWriteBlock(&addr))
    	goto err;

    // write the sprites to 00:1:1800
    // keep this in sync with sprites.s
    memcpy(BLOCK_BUFFER, pSprites, 0x100);
    addr.nOffset = 0x1800;
    if (!flashWriteBlock(&addr))
        goto err;

    memcpy(BLOCK_BUFFER, pSprites + 0x100, 0x100);
    addr.nOffset = 0x1900;
    if (!flashWriteBlock(&addr))
        goto err;

    return CART_RV_OK;
err:
	return CART_RV_ERR;
}

/******************************************************************************/
/**
 * Do all preparations to write a file to flash.
 * If m_bFileUSB is true, read the file from USB.
 *
 * If this function returns CART_RV_OK, the file has been opened successfully.
 */
static uint8_t writeOpenFile(const char* pStrImageType)
{
    uint8_t rv;

    checkFlashType();

    if (m_bFileUSB)
    {
        utilOpenFile(UTIL_USE_USB);
    }
    else
    {
        do
        {
            rv = fileDlg(pStrImageType);
            if (!rv)
                return CART_RV_ERR;

            rv = utilOpenFile(0);
            if (rv == 1)
                screenPrintSimpleDialog(apStrFileOpenError);
        }
        while (rv != OPEN_FILE_OK);
    }

    if (screenAskEraseDialog() != BUTTON_ENTER)
    {
        utilCloseFile();
        return CART_RV_ERR;
    }

    refreshMainScreen();
    setStatus("Checking file");

    // make sure the right areas of the chip are erased
    progressInit();
    timerStart();
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

    g_strCartName[0] = '\0';

    setStatus("Reading CRT image");
    if (!readCartHeader())
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        return CART_RV_ERR;
    }

    // this will show the cartridge type from the header
    refreshMainScreen();

    if (writeStartUpCode(&nBankOffset) != CART_RV_OK)
        return CART_RV_ERR;

    while ((rv = readNextHeader()) != CART_RV_EOF)
    {
        if (rv == CART_RV_OK)
        {
            m_nBank += nBankOffset;

            if ((m_nAddress == (uint16_t) ROM0_BASE) && (m_nSize <= 0x4000))
            {
                if (m_nSize > 0x2000)
                {
                    if (!flashWriteBankFromFile(m_nBank, 0, 0x2000) ||
                        !flashWriteBankFromFile(m_nBank, 1, m_nSize - 0x2000))
                        return CART_RV_ERR;
                }
                else
                {
                    if (!flashWriteBankFromFile(m_nBank, 0, m_nSize))
                        return CART_RV_ERR;
                }
            }
            else if (((m_nAddress == (uint16_t) ROM1_BASE) ||
                      (m_nAddress == (uint16_t) ROM1_BASE_ULTIMAX)) &&
                     (m_nSize <= 0x2000))
            {
                if (!flashWriteBankFromFile(m_nBank, 1, m_nSize))
                    return CART_RV_ERR;
            }
            else
            {
                screenPrintSimpleDialog(apStrUnsupportedCRTData);
                return CART_RV_ERR;
            }
        }
        else
        {
            screenPrintSimpleDialog(apStrChipReadError);
            return CART_RV_ERR;
        }
    }

    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write a BIN image from the given file to flash, either LOROM or HIROM,
 * beginning at nStartBank (which may have FLASH_8K_SECTOR_BIT set).
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t __fastcall__ writeBinImage(uint8_t nStartBank,
                                          uint8_t nChip,
                                          uint8_t interleaved)
{
    EasyFlashAddr addr;
    int      nBytes;
    uint8_t  pad;

    g_strCartName[0] = '\0';

    // this will show the cartridge type from the header
    refreshMainScreen();

    addr.nSlot = g_nSelectedSlot;
    addr.nBank = nStartBank;
    addr.nChip = nChip;
    addr.nOffset = 0;
    do
    {
        nBytes = utilRead(BLOCK_BUFFER, 0x100);

        if (nBytes > 0)
        {
            // the last block may be smaller than 265 bytes, pad with 0xff (unprogrammed)
            if(nBytes & 0x00ff){
                pad = nBytes;
                do{
                    BLOCK_BUFFER[pad] = 0xff;
                }while(++pad);
            }

            if (!flashWriteBlock(&addr))
                goto retError;

            if (!flashVerifyBlock(&addr))
                goto retError;

            addr.nOffset += 0x100;
            if (addr.nOffset == 0x2000)
            {
                addr.nOffset = 0;
                if (interleaved)
                {
                    if (addr.nChip == 0)
                        addr.nChip = 1;
                    else
                    {
                        addr.nChip = 0;
                        ++addr.nBank;
                    }
                }
                else
                    ++addr.nBank;
            }
        }
    }
    while (nBytes == 0x100);

    if (addr.nOffset || addr.nBank)
    {
        utilCloseFile();
        timerStop();
        return CART_RV_OK;
    }

retError:
    utilCloseFile();
    timerStop();
    return CART_RV_ERR;
}


/******************************************************************************/
/**
 * Write a CRT image file to flash. This version doesn't need any user
 * interaction. g_strFileName must contain the file name already.
 *
 * Return 1 if everything worked well.
 */
uint8_t autoWriteCRTImage(uint8_t nSlot)
{
    uint8_t rv;

    refreshMainScreen();

    slotSelect(nSlot);
    rv = utilOpenFile(0);
    if (rv == 1)
        return 0;

    // make sure the right areas of the chip are erased
    progressInit();

    rv = writeCrtImage();
    utilCloseFile();

    if (rv == CART_RV_OK)
    {
        if (g_nSlots > 1 && g_nSelectedSlot != 0)
        {
            slotSaveName(g_strCartName, 0xff, 0xff);
        }
    }
    return 1;
}


/******************************************************************************/
/**
 * Write a CRT image file to flash.
 */
void checkWriteCRTImage(void)
{
    uint8_t rv;

    if (checkAskForEFSlot() && (writeOpenFile("CRT") == CART_RV_OK))
    {
        rv = writeCrtImage();
        utilCloseFile();
        timerStop();

        if (rv == CART_RV_OK)
        {
            if (g_nSlots > 1 && g_nSelectedSlot != 0)
            {
                slotSaveName(screenReadInput("Cartridge Name", g_strCartName),
                    0xff, 0xff);
            }
            screenPrintSimpleDialog(apStrWriteComplete);
        }
    }
}


/******************************************************************************/
/**
 * Write a KERNAL image file to the flash.
 */
void checkWriteKERNALImage(void)
{
    uint8_t nKERNAL, rv;

    slotSelect(0);
    nKERNAL = selectKERNALSlotDialog();
    if (nKERNAL != 0xff)
    {
        if (writeOpenFile("BIN") == CART_RV_OK)
        {
            rv = writeBinImage(nKERNAL | FLASH_8K_SECTOR_BIT, 0,
                               EP_NON_INTERLEAVED);
            if (rv == CART_RV_OK)
            {
                slotSaveName(screenReadInput("KERNAL Name", g_strFileName),
                             nKERNAL, 0xff);
                screenPrintSimpleDialog(apStrWriteComplete);
            }
        }
    }
}


/******************************************************************************/
/**
 * Write a freezer image file to the flash.
 */
void checkWriteFreezerImage(void)
{
    uint8_t nFreezer, rv;

    slotSelect(0);
    nFreezer = selectFreezerSlotDialog();
    if (nFreezer != 0xff)
    {
        if (writeOpenFile("BIN") == CART_RV_OK)
        {
            if (nFreezer <= 1)
                rv = writeBinImage(nFreezer * 8 + EF3_AR_BANK, 1, EP_NON_INTERLEAVED);
            else if (nFreezer == 2)
                rv = writeBinImage(EF3_SS5_BANK, 0, EP_INTERLEAVED);
            else
                rv = writeBinImage(EF3_FC3_BANK, 0, EP_INTERLEAVED);

            if (rv == CART_RV_OK)
            {
                slotSaveName(screenReadInput("Freezer Name", g_strFileName),
                             0xff, nFreezer);
                screenPrintSimpleDialog(apStrWriteComplete);
            }
        }
    }
}


/******************************************************************************/
/**
 * Write an image from USB to flash.
 */
void checkWriteImageFromUSB(void)
{
    uint8_t nType;

    nType = selectSlotTypeDialog();
    if (nType == 0xff)
        return;

    m_bFileUSB = 1;

    if (nType == EF_SLOTS)
    {
        checkWriteCRTImage();
    }
    else if (nType == KERNAL_SLOTS)
    {
        checkWriteKERNALImage();
    }
    else
    {
        checkWriteFreezerImage();
    }

    m_bFileUSB = 0;
}


/******************************************************************************/
/**
 * Write a BIN image file to the LOROM flash.
 */
void checkWriteLOROMImage(void)
{
    uint8_t rv;

    if (checkAskForEFSlot() && (writeOpenFile("BIN") == CART_RV_OK))
    {
        rv = writeBinImage(0, 0, EP_NON_INTERLEAVED);
        if (rv == CART_RV_OK)
            screenPrintSimpleDialog(apStrWriteComplete);
    }
}


/******************************************************************************/
/**
 * Write a BIN image file to the HIROM flash.
 */
void checkWriteHIROMImage(void)
{
    uint8_t rv;

    if (checkAskForEFSlot() && (writeOpenFile("BIN") == CART_RV_OK))
    {
        rv = writeBinImage(0, 1, EP_NON_INTERLEAVED);
        if (rv == CART_RV_OK)
            screenPrintSimpleDialog(apStrWriteComplete);
    }
}


/******************************************************************************/
/**
 */
void eraseAll(void)
{
    uint8_t i;

    checkFlashType();
    for (i = 0; i < g_nSlots; ++i)
    {
        slotSelect(i);
        eraseSlot();
    }
    resetCartInfo();
}


/******************************************************************************/
/**
 * Ask the user if it is okay to erase all and do so if yes.
 */
void checkEraseAll(void)
{
    if (screenAskEraseDialog() == BUTTON_ENTER)
        eraseAll();
}


/******************************************************************************/
/**
 * Ask the user if it is okay to erase a slot and do so if yes.
 */
void checkEraseSlot(void)
{
    if (g_nSlots > 1)
    {
        if (!checkAskForEFSlot())
            return;
    }

    if (screenAskEraseDialog() == BUTTON_ENTER)
    {
        checkFlashType();
        eraseSlot();

        if (g_nSelectedSlot > 0)
        {
            strcpy(utilStr, "EF Slot ");
            utilAppendDecimal(g_nSelectedSlot);
            slotSaveName(utilStr, 0xff, 0xff);
        }
        resetCartInfo();
    }
}


/******************************************************************************/
/**
 * Ask the user if it is okay to erase a KERNAL and do so if yes.
 */
void checkEraseKERNAL(void)
{
    uint8_t nKERNAL;

    slotSelect(0);
    nKERNAL = selectKERNALSlotDialog();
    if (nKERNAL != 0xff)
    {
        if (screenAskEraseDialog() == BUTTON_ENTER)
        {
            checkFlashType();
            eraseSector(nKERNAL | FLASH_8K_SECTOR_BIT, 0);
            strcpy(utilStr, "KERNAL ");
            utilAppendDecimal(nKERNAL + 1);
            slotSaveName(utilStr, nKERNAL, 0xff);
            resetCartInfo();
        }
    }
}

/******************************************************************************/
/**
 * Ask the user if it is okay to erase a freezer and do so if yes.
 */
void checkEraseFreezer(void)
{
    uint8_t nFreezer;

    slotSelect(0);
    nFreezer = selectFreezerSlotDialog();
    if (nFreezer != 0xff)
    {
        if (screenAskEraseDialog() == BUTTON_ENTER)
        {
            checkFlashType();
            if (nFreezer <= 1)
            {
                eraseSector(nFreezer * 8 + EF3_AR_BANK, 1);
                strcpy(utilStr, "Replay Slot ");
                utilAppendDecimal(nFreezer + 1);
            }
            else if (nFreezer == 2)
            {
                eraseSector(EF3_SS5_BANK, 0);
                eraseSector(EF3_SS5_BANK, 1);
                strcpy(utilStr, "SS5 Slot");
            }
            else
            {
                eraseSector(EF3_FC3_BANK, 0);
                eraseSector(EF3_FC3_BANK, 1);
                strcpy(utilStr, "FC3 Slot");
            }

            slotSaveName(utilStr, 0xff, nFreezer);
            resetCartInfo();
        }
    }
}
