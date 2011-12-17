/*
 * flash.c
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <conio.h>

#include "flash.h"
#include "screen.h"
#include "eapiglue.h"
#include "progress.h"
#include "easyprog.h"
#include "torturetest.h"
#include "texts.h"
#include "util.h"

/******************************************************************************/

/// map chip index to normal address
static uint8_t* const apNormalRomBase[2] = { ROM0_BASE, ROM1_BASE };

/// map chip index to Ultimax address
static uint8_t* const apUltimaxRomBase[2] = { ROM0_BASE, ROM1_BASE_ULTIMAX };

// EAPI signature
static const unsigned char aEAPISignature[] =
{
        0x65, 0x61, 0x70, 0x69 /* "EAPI" */
};

// EAPI signature
static const unsigned char aEFNameSignature[] =
{
        0x65, 0x66, 0x2d, 0x6e, 0x41, 0x4d, 0x45, 0x3a /* "EF-Name:" */
};

#define FLASH_WRITE_SIZE 256

/******************************************************************************/
/**
 * Erase a 64k sector that contains the given bank and print the progress.
 *
 * If nBank has FLASH_8K_SECTOR_BIT set, erase an 8k sector.
 * This is only possible on devices which have 8k sectors. It will simply
 * fail or erase 64k on others.
 *
 * return 1 for success, 0 for failure
 */
uint8_t eraseSector(uint8_t nBank, uint8_t nChip)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    uint8_t  nBanksToErase;

    // for 64k: start erasing at the first bank of this flash sector
    nBanksToErase = 1;
    if (!(nBank & FLASH_8K_SECTOR_BIT))
    {
        nBanksToErase = FLASH_BANKS_ERASE_AT_ONCE;
        nBank &= ~(FLASH_BANKS_ERASE_AT_ONCE - 1);
    }

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    eapiSetBank(nBank);

    progressSetMultipleBanksState(nBank, nChip, nBanksToErase,
                                  PROGRESS_ERASING);

    // send the erase command
    if (eapiSectorErase(pUltimaxBase))
    {
        progressSetMultipleBanksState(nBank, nChip, nBanksToErase,
                                      PROGRESS_ERASED);
        return 1;
    }
    else
    {
        progressSetMultipleBanksState(nBank, nChip, nBanksToErase,
                                      PROGRESS_UNTOUCHED);
        screenPrintSimpleDialog(apStrEraseFailed);
    }
    return 0;
}

/******************************************************************************/
/**
 * Erase all sectors of all chips of the current slot (or: the whole EF1).
 *
 * return 1 for success, 0 for failure
 */
uint8_t eraseSlot(void)
{
    uint8_t nBank;
    uint8_t nChip;

    for (nChip = 0; nChip < 2; ++nChip)
    {
        // erase 64 kByte = 8 banks at once
        for (nBank = 0; nBank < FLASH_NUM_BANKS; nBank
                += FLASH_BANKS_ERASE_AT_ONCE)
        {
            if (!eraseSector(nBank, nChip))
                return 0;
        }
    }

    return 1;
}


/******************************************************************************/
/**
 * Write a block of 256 bytes from BLOCK_BUFFER to the flash.
 * The whole block must be located in one bank and in one flash chip.
 * If the flash block has an unknown state, erase it.
 *
 * return 1 for success, 0 for failure
 */
uint8_t __fastcall__ flashWriteBlock(uint8_t nBank, uint8_t nChip,
                                     uint16_t nOffset)
{
    uint16_t rv;
    uint8_t* pDest;
    uint8_t* pNormalBase;

    utilStr[0] = 0;
    utilAppendFlashAddr(nBank, nChip, nOffset);
    setStatus(utilStr);

    if (progressGetStateAt(nBank, nChip) == PROGRESS_UNTOUCHED)
    {
        if (!eraseSector(nBank, nChip))
        {
            screenPrintSimpleDialog(apStrEraseFailed);
            return 0;
        }
    }

    eapiSetBank(nBank);
    pNormalBase = apNormalRomBase[nChip];

    // when we write, we have to use the Ultimax address space
    pDest = apUltimaxRomBase[nChip] + nOffset;

    progressSetBankState(nBank, nChip, PROGRESS_WRITING);
    rv = eapiGlueWriteBlock(pDest);
    if (rv != 0x100)
    {
         progressSetBankState(nBank, nChip, PROGRESS_UNTOUCHED);
         screenPrintSimpleDialog(apStrFlashWriteFailed);
         return 0;
    }

    progressSetBankState(nBank, nChip, PROGRESS_PROGRAMMED);
    return 1;
}


/******************************************************************************/
/**
 * Compare 256 bytes of flash contents and BLOCK_BUFFER contents.
 * The whole block must be located in one bank and in one flash
 * chip.
 *
 * If there is an error, report it to the user
 *
 * return 1 for success (same), 0 for failure
 */
uint8_t __fastcall__ flashVerifyBlock(uint8_t nBank, uint8_t nChip,
                                      uint16_t nOffset)
{
    uint8_t* pNormalBase;
    uint8_t* pFlash;

    progressSetBankState(nBank, nChip, PROGRESS_VERIFYING);

    pNormalBase = apNormalRomBase[nChip];
    pFlash      = pNormalBase + nOffset;

    pFlash = efVerifyFlash(pFlash);
    if (pFlash)
    {
        nOffset = pFlash - pNormalBase;
        screenPrintVerifyError(nBank, nChip, nOffset,
                BLOCK_BUFFER[nOffset], *pFlash);
        return 0;
    }

    progressSetBankState(nBank, nChip, PROGRESS_PROGRAMMED);
    return 1;
}


/******************************************************************************/
/**
 * Write a block of bytes from the currently active input to the flash.
 * The block will be written to offset 0 of this bank/chip.
 * The whole block must be located in one bank and in one flash chip.
 *
 * return 1 for success, 0 for failure
 */
uint8_t flashWriteBankFromFile(uint8_t nBank, uint8_t nChip,
                                uint16_t nSize)
{
    uint8_t  bReplaceEAPI;
    uint8_t  oldState;
    uint16_t nOffset;
    uint16_t nBytes;

    nOffset      = 0;
    bReplaceEAPI = 0;
    while (nSize)
    {
        nBytes = (nSize > FLASH_WRITE_SIZE) ? FLASH_WRITE_SIZE : nSize;

        oldState = progressGetStateAt(nBank, nChip);
        progressSetBankState(nBank, nChip, PROGRESS_READING);

        if (utilRead(BLOCK_BUFFER, nBytes) != nBytes)
        {
            screenPrintSimpleDialog(apStrFileTooShort);
            progressSetBankState(nBank, nChip, PROGRESS_UNTOUCHED);
            return 0;
        }

        progressSetBankState(nBank, nChip, oldState);

        // Check if EAPI has to be replaced
        if (nBank == 0 && nChip == 1)
        {
            if (nOffset == 0x1800 &&
                memcmp(BLOCK_BUFFER, aEAPISignature, sizeof(aEAPISignature)) == 0)
                bReplaceEAPI = 1;
            if (nOffset == 0x1b00 &&
                memcmp(BLOCK_BUFFER, aEFNameSignature, sizeof(aEFNameSignature)) == 0)
            {
                memcpy(g_strCartName, BLOCK_BUFFER + sizeof(aEFNameSignature),
                       EF_CART_NAME_LEN);
                g_strCartName[EF_CART_NAME_LEN] = '\0';
                refreshMainScreen();
            }
        }

        if (bReplaceEAPI)
        {
            if (nOffset == 0x1800)
                memcpy(BLOCK_BUFFER, EAPI_LOAD_TO, 0x100);
            else if (nOffset == 0x1900)
                memcpy(BLOCK_BUFFER, EAPI_LOAD_TO + 0x100, 0x100);
            else if (nOffset == 0x1a00)
            {
                memcpy(BLOCK_BUFFER, EAPI_LOAD_TO + 0x200, 0x100);
                bReplaceEAPI = 0;
            }
        }

        if (!flashWriteBlock(nBank, nChip, nOffset))
            return 0;

        if (!flashVerifyBlock(nBank, nChip, nOffset))
            return 0;

        nSize -= nBytes;
        nOffset += nBytes;
        refreshElapsedTime();
    }

    return 1;
}

