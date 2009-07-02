/*
 * flash.c
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <conio.h> // kann wieder raus
#include <unistd.h>

#include "flash.h"
#include "screen.h"
#include "flashcode.h"
#include "easyprog.h"

/******************************************************************************/

/// map chip index to normal address
static uint8_t* const apNormalRomBase[2] = { ROM0_BASE, ROM1_BASE };

/// map chip index to Ultimax address
static uint8_t* const apUltimaxRomBase[2] = { ROM0_BASE, ROM1_BASE_ULTIMAX };

#define FLASH_WRITE_SIZE 1024
static uint8_t buffer[FLASH_WRITE_SIZE];

/******************************************************************************/
/**
 * Check the program or erase progress of the flash chip at the given base
 * address (normal base).
 *
 * Return 1 for success, 0 for error
 */
static uint8_t __fastcall__ checkFlashProgress(uint8_t* pNormalBase)
{
    uint8_t  nSame, st1, st2;

    // wait as long as the toggle bit toggles
    nSame = 0;
    do
    {
        st1 = *((volatile uint8_t*) pNormalBase);
        st2 = *((volatile uint8_t*) pNormalBase);

        // must be same two consecutive times
        if (st1 == st2)
            ++nSame;
        else
            nSame = 0;

    } while ((nSame < 2) && !(st2 & FLASH_ALG_ERROR_BIT));

    // read once more to catch the case status => data
    st1 = *((volatile uint8_t*) pNormalBase);
    st2 = *((volatile uint8_t*) pNormalBase);

    // not toggling anymore => success
    if (st1 == st2)
    {
        return 1;
    }
    return 0;
}


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

    sprintf(strStatus, "Erasing %02X:%X:%04X",  nBank, nChip, 0);
    setStatus(strStatus);
    sleep(1);
    setStatus("OK");
    return 1;
}
#else
uint8_t eraseSector(uint8_t nBank, uint8_t nChip)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    char strStatus[41];

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    flashCodeSetBank(nBank);

    // send the erase command
    flashCodeSectorErase(pUltimaxBase);

    // wait 50 us for the algorithm being started
    // this is done by printing the status
    sprintf(strStatus, "Erasing %02X:%X:%04X",  nBank, nChip, 0);
    setStatus(strStatus);

    if (checkFlashProgress(pNormalBase))
    {
        setStatus("OK");
        return 1;
    }

    sprintf(strStatus, "Erase error %02X:%X:%04X", nBank, nChip, 0);
    setStatus(strStatus);
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

    // erase 64 kByte = 8 banks at once (29F040)
    for (nBank = 0; nBank < FLASH_NUM_BANKS; nBank += 8)
    {
        if (!eraseSector(nBank, 0))
            return 0;

        if (!eraseSector(nBank, 1))
            return 0;
    }

    return 1;
}


/******************************************************************************/
/**
 * Write a block of bytes to the flash. The bank must already be set up.
 * The whole block must be located in one bank and in one flash chip.
 *
 * return 1 for success, 0 for failure
 */
uint8_t flashWriteBlock(uint8_t nChip, uint16_t nOffset, uint16_t nSize,
                        uint8_t* pBlock)
{
    uint16_t nRemaining;
    uint8_t* pDest;
    uint8_t* pNormalBase;
#ifndef EASYFLASH_FAKE
    char strStatus[41];
#endif

    pNormalBase  = apNormalRomBase[nChip];

    // when we write, we have to use the Ultimax address space
    pDest        = apUltimaxRomBase[nChip] + nOffset;

    for (nRemaining = nSize; nRemaining; --nRemaining)
    {
        // send the write command
        flashCodeWrite(pDest++, *pBlock++);
#ifndef EASYFLASH_FAKE
        if (!checkFlashProgress(pNormalBase))
        {
            // todo: Show a real error message
            sprintf(strStatus, "Write error %02X:%X:%04X",
                    0 /*nBank*/, nChip, nOffset);
            setStatus(strStatus);
            for (;;);
        }
#endif
    }

	addBytesFlashed(nSize);
    return 1;
}


/******************************************************************************/
/**
 * Compare a block of bytes with the flash content. The bank must already be
 * set up. The whole block must be located in one bank and in one flash chip.
 *
 * return 1 for success (same), 0 for failure
 */
uint8_t flashVerifyBlock(uint8_t nChip, uint16_t nOffset, uint16_t nSize,
                        uint8_t* pBlock)
{
    uint16_t nRemaining;
    uint8_t* pDest;
    uint8_t* pNormalBase;
    uint8_t  nFileVal;
    uint8_t  nFlashVal;
#ifndef EASYFLASH_FAKE
    char strStatus[41];
#endif

    pNormalBase  = apNormalRomBase[nChip];
    pDest = pNormalBase + nOffset;

    for (nRemaining = nSize; nRemaining; --nRemaining)
    {
        nFlashVal = *pDest++;
        nFileVal  = *pBlock++;
#ifndef EASYFLASH_FAKE
        if (nFlashVal != nFileVal)
        {
            sprintf(strStatus, "%02X:%X:%04X: file %02X != flash %02X",
                    0 /*nBank*/, nChip, nOffset,
                    nFileVal, nFlashVal);
            if (screenPrintTwoLinesDialog("Verify error at", strStatus) ==
                BUTTON_STOP)
                return 0;
        }
#endif
        ++nOffset;
    }

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

    flashCodeSetBank(nBank);

    nOffset = 0;
    while (nSize)
    {
        nBytes = (nSize > FLASH_WRITE_SIZE) ? FLASH_WRITE_SIZE : nSize;

        sprintf(strStatus, "Reading %d bytes from file", nBytes);
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
            sprintf(strStatus, "Flashing %d bytes to %02X:%X:%04X", nBytes,
                    nBank, nChip, nOffset);
            setStatus(strStatus);

            if (!flashWriteBlock(nChip, nOffset, nBytes, buffer))
                return 0;
        }

        sprintf(strStatus, "Verifying %d bytes at %02X:%X:%04X", nBytes,
                nBank, nChip, nOffset);
        setStatus(strStatus);
        if (!flashVerifyBlock(nChip, nOffset, nBytes, buffer))
            return 0;

        nSize -= nBytes;
        nOffset += nBytes;
    }

    return 1;
}

