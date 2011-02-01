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
static const unsigned char pStrEAPISignature[] =
{
        0x65, 0x61, 0x70, 0x69 /* "EAPI" */
};

#define FLASH_WRITE_SIZE 256
static uint8_t buffer[FLASH_WRITE_SIZE];

/******************************************************************************/
/**
 * Erase a sector that contains the given bank and print the progress.
 *
 * return 1 for success, 0 for failure
 */
uint8_t eraseSector(uint8_t nBank, uint8_t nChip)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;

    // start erasing at the first bank of this flash sector
    // we assume FLASH_BANKS_ERASE_AT_ONCE is a power of 2
    nBank &= ~(FLASH_BANKS_ERASE_AT_ONCE - 1);

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    eapiSetBank(nBank);

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_ERASING);

    // send the erase command
    if (eapiSectorErase(pUltimaxBase))
    {
        progressSetMultipleBanksState(nBank, nChip,
                                      FLASH_BANKS_ERASE_AT_ONCE,
                                      PROGRESS_ERASED);
        return 1;
    }
    else
    {
        progressSetMultipleBanksState(nBank, nChip,
                                      FLASH_BANKS_ERASE_AT_ONCE,
                                      PROGRESS_UNTOUCHED);
        screenPrintSimpleDialog(apStrEraseFailed);
    }
    return 0;
}


/******************************************************************************/
/**
 * Erase all sectors of all chips.
 *
 * return 1 for success, 0 for failure
 */
uint8_t eraseAll(void)
{
    uint8_t nBank;
    uint8_t nChip;

    for (nChip = 0; nChip < 2; ++nChip)
    {
        // erase 64 kByte = 8 banks at once (29F040)
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
 * Write a block of 256 bytes to the flash.
 * The whole block must be located in one bank and in one flash chip.
 * If the flash block has an unknown state, erase it.
 *
 * return 1 for success, 0 for failure
 */
uint8_t __fastcall__ flashWriteBlock(uint8_t nBank, uint8_t nChip,
                                     uint16_t nOffset, uint8_t* pBlock)
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
    rv = eapiGlueWriteBlock(pDest, pBlock);
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
 * Compare 256 bytes of flash contents and RAM contents.
 * The whole block must be located in one bank and in one flash
 * chip.
 *
 * If there is an error, report it to the user
 *
 * return 1 for success (same), 0 for failure
 */
uint8_t __fastcall__ flashVerifyBlock(uint8_t nBank, uint8_t nChip,
                                      uint16_t nOffset, uint8_t* pBlock)
{
    uint8_t* pNormalBase;
    uint8_t* pFlash;

    progressSetBankState(nBank, nChip, PROGRESS_VERIFYING);

    pNormalBase = apNormalRomBase[nChip];
    pFlash      = pNormalBase + nOffset;

    pFlash = tortureTestVerifyFlash(pFlash, pBlock);
    if (pFlash)
    {
        nOffset = pFlash - pNormalBase;
        screenPrintVerifyError(nBank, nChip, nOffset,
                               pBlock[nOffset], *pFlash);
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

        if (utilRead(buffer, nBytes) != nBytes)
        {
            screenPrintSimpleDialog(apStrFileTooShort);
            progressSetBankState(nBank, nChip, PROGRESS_UNTOUCHED);
            return 0;
        }

        progressSetBankState(nBank, nChip, oldState);

        // Check if EAPI has to be replaced
        if (nBank == 0 && nChip == 1 && nOffset == 0x1800 &&
                    memcmp(buffer, pStrEAPISignature, 4) == 0)
            bReplaceEAPI = 1;

        if (bReplaceEAPI)
        {
            if (nOffset == 0x1800)
                memcpy(buffer, EAPI_LOAD_TO, 0x100);
            else if (nOffset == 0x1900)
                memcpy(buffer, EAPI_LOAD_TO + 0x100, 0x100);
            else if (nOffset == 0x1a00)
                memcpy(buffer, EAPI_LOAD_TO + 0x200, 0x100);
        }

        if (!flashWriteBlock(nBank, nChip, nOffset, buffer))
            return 0;

        if (!flashVerifyBlock(nBank, nChip, nOffset, buffer))
            return 0;

        nSize -= nBytes;
        nOffset += nBytes;
        refreshElapsedTime();
    }

    return 1;
}

