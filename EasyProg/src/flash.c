/*
 * flash.c
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#include "flash.h"
#include "flashcode.h"
#include "easyprog.h"

/******************************************************************************/

/// map chip index to normal address
static uint8_t* const apNormalRomBase[2] = { ROM0_BASE, ROM1_BASE };

/// map chip index to Ultimax address
static uint8_t* const apUltimaxRomBase[2] = { ROM0_BASE, ROM1_BASE_ULTIMAX };


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
 * Calculate the bank number from an offset. Each bank has 16 kByte, so simply
 * divide it by 16k.
 *
 * nOffset is the logical chip address between 0 and 1 M.
 */
uint8_t bankFromOffset(uint32_t nOffset)
{
   return nOffset / (16 * 1024);
}


/******************************************************************************/
/**
 * Calculate the chip number from an offset. Each bank has 16 kByte, the first
 * 8 kByte are in the first chip, the second 8 kByte are in the second chip.
 *
 * nOffset is the logical chip address between 0 and 1 M.
 */
uint8_t chipFromOffset(uint32_t nOffset)
{
    return (nOffset % (16 * 1024)) / (8 * 1024);
}


/******************************************************************************/
/**
 * Erase a sector and print the progress.
 * For the details about reading the progress refer to the flash spec.
 *
 * return 1 for success, 0 for failure
 */
#ifdef EASYFLASH_FAKE
uint8_t eraseSector(uint8_t nChip)
{
    char strStatus[30];

    sprintf(strStatus, "Erasing %02X:%X:%04X",  0, nChip, 0);
    setStatus(strStatus);
    sleep(1);
    setStatus("OK");
    return 1;
}
#else
uint8_t eraseSector(uint8_t nChip)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    char strStatus[30];

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    // send the erase command
    flashCodeSectorErase(pUltimaxBase);

    // wait 50 us for the algorithm being started
    // this is done by printing the status
    sprintf(strStatus, "Erasing %02X:%X:%04X",  0, nChip, 0);
    setStatus(strStatus);

    if (checkFlashProgress(pNormalBase))
    {
        setStatus("OK");
        return 1;
    }

    sprintf(strStatus, "Erase error %02X:%X:%04X", 0, nChip, 0);
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
    if (!eraseSector(0))
        return 0;

    if (!eraseSector(1))
        return 0;

    return 1;
}


/******************************************************************************/
/**
 * Write a byte and print the progress.
 * For the details about reading the progress refer to the flash spec.
 *
 * return 1 for success, 0 for failure
 */
#ifdef EASYFLASH_FAKE
uint8_t flashWrite(uint8_t nChip, uint16_t nOffset, uint8_t nVal)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    char strStatus[30];

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    // send the write command
    flashCodeWrite(pUltimaxBase + nOffset, nVal);

    return 1;
}
#else
uint8_t flashWrite(uint8_t nChip, uint16_t nOffset, uint8_t nVal)
{
    uint8_t* pUltimaxBase;
    uint8_t* pNormalBase;
    char strStatus[30];

    pNormalBase  = apNormalRomBase[nChip];
    pUltimaxBase = apUltimaxRomBase[nChip];

    // send the write command
    flashCodeWrite(pUltimaxBase + nOffset, nVal);

    if (checkFlashProgress(pNormalBase))
        return 1;

    sprintf(strStatus, "Write error %02X:%X:%04X", 0, nChip, nOffset);
    setStatus(strStatus);
    return 0;
}
#endif
