
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <ef3usb.h>
#include <eload.h>

#include "usbtool.h"


#define WRITE_DISK_ERR_WRONG_DRIVE      80


/******************************************************************************/
/**
 *
 */
static uint8_t init_eload(uint8_t drv)
{
    unsigned type;

    type = eload_set_drive_check_fastload(drv);
    if (type)
    {
        printf("Drive type %d found\n", type);
    }
    else
    {
        printf("Device %d not present\n", drv);
    }

    if (type != 2)
    {
        puts("Wrong drive type for d64 writer");
        type = 0;
    }
    return type;
}


/******************************************************************************/
/**
 * Write a d64 image to disk.
 *
 * The main program got the start command over USB already.
 */
void write_disk_d64(void)
{
    static uint8_t a_request[2];

    puts("\nd64 writer started");
    ef3usb_send_str("load");

    if (init_eload(8) == 0)
    {
        ef3usb_fclose();
        puts("exit");
        return;
    }

    puts("Preparing drive...");
    eload_prepare_drive();
    puts("Drive ok");

    puts("<= CLOSE");
    a_request[0] = 0;
    a_request[1] = 0;
    ef3usb_send_data(a_request, 2);
}
