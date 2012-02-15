/*
 * eload.h
 */

#ifndef ELOAD_H_
#define ELOAD_H_

#include <stdint.h>

#define ELOAD_OK                0
#define ELOAD_ERR_NO_SYNC       1
#define ELOAD_SECTOR_NOT_FOUND  2
#define ELOAD_HEADER_NOT_FOUND  3

/**
 * Set the device number for the drive to be used, and check the drive type.
 * The drive number and the drive type are stored internally.
 *
 * Return the drive type (see drivetype.s).
 */
int  __fastcall__ eload_set_drive_check_fastload(uint8_t dev);

/**
 * Set the device number for the drive to be used and set its type to
 * "unknown". This disables the fast loader.
 * The drive number and the drive type are stored internally.
 */
void __fastcall__ eload_set_drive_disable_fastload(uint8_t dev);


/**
 * Check if the current drive is accelerated. If no acceleration is
 * supported, the other functions will use KERNAL calls automatically.
 * eload_set_drive_* must have been called before.
 */
int eload_drive_is_fast(void);


int __fastcall__ eload_open_read(const char* name);
int eload_read_byte(void);
unsigned int __fastcall__ eload_read(void* buffer, unsigned int size);

/**
 * Receive the status byte for the previous asynchronous message, e.g. for
 * eload_write_sector.
 */
uint8_t eload_recv_status(void);

/**
 * Close the current file and cancel the drive code, if any.
 */
void eload_close(void);


/**
 * Prepare the drive to be used. This function uploads the drive code
 * if needed. It does nothing if the current drive doesn't support
 * acceleration or if it doesn't need drive code.
 * eload_set_drive_* must have been called before.
 */
void eload_prepare_drive(void);

void __fastcall__ eload_write_sector(unsigned ts, uint8_t* block);
void __fastcall__ eload_write_sector_nodma(unsigned ts, uint8_t* block);

#endif /* ELOAD_H_ */
