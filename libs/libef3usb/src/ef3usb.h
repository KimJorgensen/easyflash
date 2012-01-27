/*
 * usb.h
 *
 *  Created on: 25.10.2011
 *      Author: skoe
 */

#ifndef USB_H_
#define USB_H_

char*             ef3usb_check_cmd(void);
void __fastcall__ ef3usb_send_str(const char* p);
void              ef3usb_discard_rx(void);

/* these functions can be used after usbSendResponseLOAD(): */
unsigned int __fastcall__ ef3usb_fread(void* buffer, unsigned int size);
void                      ef3usb_fclose(void);

#endif /* USB_H_ */
