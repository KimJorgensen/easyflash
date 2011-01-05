/*
 * eload.h
 *
 *  Created on: 12.12.2010
 *      Author: skoe
 */

#ifndef ELOAD_H_
#define ELOAD_H_

#include <stdint.h>

int  __fastcall__ eload_set_drive_check_fastload(uint8_t dev);
void __fastcall__ eload_set_drive_disable_fastload(uint8_t dev);

int eload_drive_is_fast(void);

int __fastcall__ eload_open_read(const char* name);

int eload_read_byte(void);

unsigned int __fastcall__ eload_read(void* buffer, unsigned int size);

void eload_close(void);

#endif /* ELOAD_H_ */
