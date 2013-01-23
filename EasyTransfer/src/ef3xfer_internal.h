/*
 * ef3xfer_internal.h
 *
 *  Created on: 02.02.2012
 *      Author: skoe
 */

#ifndef EF3XFER_INTERNAL_H_
#define EF3XFER_INTERNAL_H_

void ef3xfer_log_ftdi_error(int reason);
void ef3xfer_log_printf(const char* p_str_format, ...);

int ef3xfer_connect_ftdi(void);

int ef3xfer_do_handshake(const char* p_str_type);

int ef3xfer_read_from_ftdi(void* p_buffer, int size);

int ef3xfer_write_to_ftdi(const void* p_buffer, int size);

int ef3xfer_d64_write(const char* p_filename, int drv, int do_format);


#endif /* EF3XFER_INTERNAL_H_ */
