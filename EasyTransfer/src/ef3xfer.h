/*
 * ef3xfer.h
 *
 *  Created on: 26.01.2012
 *      Author: skoe
 */

#ifndef EF3XFER_H_
#define EF3XFER_H_

#ifdef __cplusplus
extern "C" {
#endif

void ef3xfer_set_callbacks(
        void (*custom_log_str)(const char* str),
        void (*custom_log_progress)(int percent),
        void (*custom_log_complete)(void));

void ef3xfer_transfer(const char* p_str_filename);

#ifdef __cplusplus
}
#endif

#endif /* EF3XFER_H_ */
