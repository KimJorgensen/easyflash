/*
 * flash.c
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <cbm.h>
#include <unistd.h>

#include "flash.h"
#include "screen.h"
#include "flashcode.h"
#include "progress.h"
#include "easyprog.h"

/******************************************************************************/

/// map chip index to normal address
static uint8_t* const apNormalRomBase[2] = { ROM0_BASE, ROM1_BASE };

/// map chip index to Ultimax address
static uint8_t* const apUltimaxRomBase[2] = { ROM0_BASE, ROM1_BASE_ULTIMAX };

#define FLASH_WRITE_SIZE 256
static uint8_t buffer[FLASH_WRITE_SIZE];

/******************************************************************************/
/**
 * Erase a sector and print the progress.
 * For the details about reading the progress refer to the flash spec.
 *
 * return 1 for success, 0 for failure
 */
#ifdef EASYFLASH_FAKE
uint8_t eraseSector(uint8_t nBank, uint8_t nChip)
{
    char strStatus[41];

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_WORKING);

    sprintf(strStatus, "Erasing %02X:%X:%04X",  nBank, nChip, 0);
    setStatus(strStatus);
    sleep(1);

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_ERASED);

    setStatus("OK");
    return 1;
}
#else
uint8_t eraseSector(uint8_t nBank, uint8_t nChip)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    char strStatus[41];

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_WORKING);

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    flashCodeSetBank(nBank);

    // send the erase command
    flashCodeSectorErase(pUltimaxBase);

    // wait 50 us for the algorithm being started
    // this is done by printing the status
    sprintf(strStatus, "Erasing %02X:%X:%04X",  nBank, nChip, 0);
    setStatus(strStatus);

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_ERASED);

    if (flashCodeCheckProgress(pNormalBase))
    {
        setStatus("OK");
        return 1;
    }

    sprintf(strStatus, "Erase error at %02X:%X:%04X", nBank, nChip, 0);
    setStatus(strStatus);
    screenPrintSimpleDialog(apStrEraseFailed);
    return 0;
}
#endif


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
    uint16_t nRemaining;
    uint8_t* pDest;
    uint8_t* pNormalBase;
    char strStatus[41];

    if (progressGetStateAt(nBank, nChip) == PROGRESS_UNTOUCHED)
    {
        if (!eraseSector(nBank, nChip))
        {
            // todo: Show a real error message
            return 0;
        }
    }

    sprintf(strStatus, "Writing to %02X:%X:%04X", nBank, nChip,
            nOffset);
    setStatus(strStatus);

    flashCodeSetBank(nBank);
    pNormalBase  = apNormalRomBase[nChip];

    // when we write, we have to use the Ultimax address space
    pDest        = apUltimaxRomBase[nChip] + nOffset;

    progressSetBankState(flashCodeGetBank(), nChip, PROGRESS_WORKING);
    for (nRemaining = 256; nRemaining; --nRemaining)
    {
         // send the write command
         flashCodeWrite(pDest++, *pBlock++);

         // we don't check the result, because we verify anyway
         flashCodeCheckProgress(pNormalBase);
    }

    progressSetBankState(flashCodeGetBank(), nChip, PROGRESS_PROGRAMMED);
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
static uint8_t __fastcall__ flashVerifyBlock(uint8_t nBank, uint8_t nChip,
                                             uint16_t nOffset, uint8_t* pBlock)
{
    uint8_t* pNormalBase;
    uint8_t* pFlash;
    char strStatus[41];

    sprintf(strStatus, "Verifying %02X:%X:%04X", nBank, nChip, nOffset);
    setStatus(strStatus);

    pNormalBase = apNormalRomBase[nChip];
    pFlash      = pNormalBase + nOffset;

#ifndef EASYFLASH_FAKE
    pFlash = flashCodeVerifyFlash(pFlash, pBlock);
    if (pFlash)
    {
        nOffset = pFlash - pNormalBase;
        sprintf(strStatus, "%02X:%X:%04X: file %02X != flash %02X",
                flashCodeGetBank(), nChip, nOffset,
                pBlock[nOffset], *pFlash);

        screenPrintTwoLinesDialog("Verify error at", strStatus);
        return 0;
    }
#endif

    return 1;
}


/******************************************************************************/
/**
 * Write a block of bytes to the flash.
 * The block will be written to offset 0 of this bank/chip.
 * The whole block must be located in one bank and in one flash chip.
 *
 * If bWrite is 0, verify only.
 *
 * return 1 for success, 0 for failure
 */
uint8_t flashWriteBlockFromFile(uint8_t nBank, uint8_t nChip,
                                uint16_t nSize, uint8_t bWrite, uint8_t lfn)
{
    uint16_t nOffset;
    uint16_t nBytes;
    char strStatus[41];

    nOffset = 0;
    while (nSize)
    {
        nBytes = (nSize > FLASH_WRITE_SIZE) ? FLASH_WRITE_SIZE : nSize;

        sprintf(strStatus, "Reading from file");
        setStatus(strStatus);

        if (cbm_read(lfn, buffer, nBytes) != nBytes)
        {
            // todo: Show a real error message
            setStatus("File too short");
            for (;;)
                ;
            return 0;
        }

        if (bWrite)
        {
            if (!flashWriteBlock(nBank, nChip, nOffset, buffer))
                return 0;
        }

        if (!flashVerifyBlock(nBank, nChip, nOffset, buffer))
            return 0;

        nSize -= nBytes;
        nOffset += nBytes;
    }

    return 1;
}

