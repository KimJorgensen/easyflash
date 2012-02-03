
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <c64.h>

#include <ef3usb.h>
#include <eload.h>

#include "usbtool.h"


#define DISK_STATUS_MAGIC            0x52

/* These error codes are the same as the ones for 1541 job codes */
#define DISK_STATUS_OK               0x01 /* Everything OK */
#define DISK_STATUS_HEADER_NOT_FOUND 0x02 /* Header block not found */
#define DISK_STATUS_SYNC_NOT_FOUND   0x03 /* SYNC not found */
#define DISK_STATUS_DATA_NOT_FOUND   0x04 /* Data block not found */
#define DISK_STATUS_DATA_CHK_ERR     0x05 /* Checksum error in data block */
#define DISK_STATUS_VERIFY_ERR       0x07 /* Verify error */
#define DISK_STATUS_WRITE_PROTECTED  0x08 /* Disk write protected */
#define DISK_STATUS_HEADER_CHK_ERR   0x09 /* Checksum error in header block */
#define DISK_STATUS_ID_MISMATCH      0x0b /* Id mismatch */
#define DISK_STATUS_NO_DISK          0x0f /* Disk not inserted */


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
    static uint8_t a_status[2];
    static uint8_t a_ts[2 + 22];
    static uint8_t a_track_data[21][256];
    uint8_t i, n_track, n_sector;

    puts("\nd64 writer started");
    ef3usb_send_str("load");

    if (init_eload(8) == 0)
    {
        ef3usb_fclose();
        puts("exit");
        return;
    }

    eload_prepare_drive();
    puts("Drive ready");

    // disable VIC-II DMA
    VIC.ctrl1 &= 0xef;
    while (VIC.rasterline != 255)
    {}

    for (;;)
    {
        a_status[0] = DISK_STATUS_MAGIC;
        a_status[1] = DISK_STATUS_OK;
        ef3usb_send_data(a_status, 2);

        ef3usb_receive_data(a_ts, sizeof(a_ts));
        if (a_ts[1] == 0)
            break;

        /* load the number of sectors for this track */
        ef3usb_receive_data(a_track_data, a_ts[1] * 256);

        n_track = a_ts[0];
        i = 2;
        while ((n_sector = a_ts[i]) != 0xff)
        {
            eload_write_sector_nodma((n_track << 8) | n_sector,
                                     a_track_data[n_sector]);
            ++i;
        }
    }

    // enable VIC-II DMA
    VIC.ctrl1 |= 0x10;
}
