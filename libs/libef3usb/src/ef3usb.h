/*
 * usb.h
 *
 *  Created on: 25.10.2011
 *      Author: skoe
 */

#ifndef USB_H_
#define USB_H_

#include <stdint.h>

char*             ef3usb_check_cmd(void);
void __fastcall__ ef3usb_send_data(const uint8_t* data, uint16_t len);
void __fastcall__ ef3usb_send_str(const char* p);
void              ef3usb_discard_rx(void);

/* these functions can be used after ef3usb_send_str("load"): */
unsigned int __fastcall__ ef3usb_fread(void* buffer, unsigned int size);
void*                     ef3usb_fload(void);
void                      ef3usb_fclose(void);

#endif /* USB_H_ */
