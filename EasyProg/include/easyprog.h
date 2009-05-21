/*
 * easyprog.h
 *
 *  Created on: 20.05.2009
 *      Author: skoe
 */

#ifndef EASYPROG_H_
#define EASYPROG_H_

/// Manufacturer and Device ID
#define FLASH_TYPE_AMD_AM29F040  0x01A4

/// This bit is set in 29F040 when algorithm is running
#define FLASH_ALG_RUNNING_BIT   0x08

/// This bit is set when an algorithm times out (error)
#define FLASH_ALG_ERROR_BIT     0x20


void setStatus(const char* pStrStatus);


#endif /* EASYPROG_H_ */
