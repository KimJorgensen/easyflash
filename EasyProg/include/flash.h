/*
 * flash.h
 *
 *  Created on: 21.05.2009
 *      Author: skoe
 */

#ifndef FLASH_H_
#define FLASH_H_

/// Address of Low ROM Chip
#define ROM0_BASE           ((uint8_t*) 0x8000)

/// Address of High ROM Chip
#define ROM1_BASE           ((uint8_t*) 0xA000)

/// Address of High ROM when being in Ultimax mode
#define ROM1_BASE_ULTIMAX   ((uint8_t*) 0xE000)

uint8_t bankFromOffset(uint32_t offset);
uint8_t chipFromOffset(uint32_t offset);

uint8_t eraseSector(uint8_t nChip);
uint8_t eraseAll(void);
uint8_t flashWrite(uint8_t nChip, uint16_t nOffset, uint8_t nVal);

#endif /* FLASH_H_ */
