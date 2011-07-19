/*
 * image_detect.h
 *
 *  Created on: 17.07.2011
 *      Author: skoe
 */

#ifndef IMAGE_DETECT_H_
#define IMAGE_DETECT_H_

#include <stdint.h>

#define IMAGE_SIGNATURE_LEN 8

typedef struct image_fingerprint_s
{
    uint16_t        offset;
    const uint8_t*  signature;
    const char*     name;
} image_fingerprint_t;


#endif /* IMAGE_DETECT_H_ */
