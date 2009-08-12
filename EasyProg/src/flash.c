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
#include "texts.h"

/******************************************************************************/

/// map chip index to normal address
static uint8_t* const apNormalRomBase[2] = { ROM0_BASE, ROM1_BASE };

/// map chip index to Ultimax address
static uint8_t* const apUltimaxRomBase[2] = { ROM0_BASE, ROM1_BASE_ULTIMAX };

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
    char strStatus[41];

    // start erasing at the first bank of this flash sector
    // we assume FLASH_BANKS_ERASE_AT_ONCE is a power of 2
    nBank &= ~(FLASH_BANKS_ERASE_AT_ONCE - 1);

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_WORKING);

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    flashCodeSetBank(nBank);

#ifndef EASYFLASH_FAKE
    // send the erase command
    flashCodeSectorErase(pUltimaxBase);
#endif

    // wait 50 us for the algorithm being started
    // this is done by printing the status
    sprintf(strStatus, "Erasing %02X:%X:%04X",  nBank, nChip, 0);
    setStatus(strStatus);

    progressSetMultipleBanksState(nBank, nChip,
                                  FLASH_BANKS_ERASE_AT_ONCE,
                                  PROGRESS_ERASED);

#ifndef EASYFLASH_FAKE
    if (flashCodeCheckProgress(pNormalBase))
    {
        setStatus("OK");
        return 1;
    }
#else
    sleep(1);
#endif

    sprintf(strStatus, "Erase error at %02X:%X:%04X", nBank, nChip, 0);
    setStatus(strStatus);
    screenPrintSimpleDialog(apStrEraseFailed);
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
    uint16_t nRemaining;
    uint8_t* pDest;
    uint8_t* pNormalBase;
    char strStatus[41];

    if (progressGetStateAt(nBank, nChip) == PROGRESS_UNTOUCHED)
    {
        if (!eraseSector(nBank, nChip))
        {
            screenPrintSimpleDialog(apStrEraseFailed);
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
         if (!flashCodeCheckProgress(pNormalBase))
         {
             screenPrintSimpleDialog(apStrFlashWriteFailed);
             return 0;
         }
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
        screenPrintVerifyError(flashCodeGetBank(), nChip, nOffset,
                               pBlock[nOffset], *pFlash);
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
 * return 1 for success, 0 for failure
 */
uint8_t flashWriteBlockFromFile(uint8_t nBank, uint8_t nChip,
                                uint16_t nSize, uint8_t lfn)
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

        if (!flashWriteBlock(nBank, nChip, nOffset, buffer))
            return 0;

        if (!flashVerifyBlock(nBank, nChip, nOffset, buffer))
            return 0;

        nSize -= nBytes;
        nOffset += nBytes;
    }

    return 1;
}

