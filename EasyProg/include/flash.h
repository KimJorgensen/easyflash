/*
 * flash.h
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#ifndef FLASH_H_
#define FLASH_H_

#include <stdint.h>

/// Manufacturer and Device ID
#define FLASH_TYPE_AMD_AM29F040  0x01A4

/// This bit is set in 29F040 when algorithm is running
#define FLASH_ALG_RUNNING_BIT   0x08

/// This bit is set when an algorithm times out (error)
#define FLASH_ALG_ERROR_BIT     0x20

/// Number of Banks when using 2 * 512 kByte
#define FLASH_NUM_BANKS     64

/// Address of Low ROM Chip
#define ROM0_BASE           ((uint8_t*) 0x8000)

/// Address of High ROM Chip
#define ROM1_BASE           ((uint8_t*) 0xA000)

/// Address of High ROM when being in Ultimax mode
#define ROM1_BASE_ULTIMAX   ((uint8_t*) 0xE000)

uint8_t bankFromOffset(uint32_t offset);
uint8_t chipFromOffset(uint32_t offset);

uint8_t eraseSector(uint8_t nBank, uint8_t nChip);

uint8_t eraseAll(void);

uint8_t flashWrite(uint8_t nChip, uint16_t nOffset, uint8_t nVal);

uint8_t flashWriteBlock(uint8_t nChip, uint16_t nOffset, uint16_t nSize,
                        uint8_t* pBlock);

uint8_t flashWriteBlockFromFile(uint8_t nBank, uint8_t nChip,
                                uint16_t nSize, uint8_t lfn);

#endif /* FLASH_H_ */