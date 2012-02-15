
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

#define D64_MAX_SECTORS 21 /* 0..20 */
#define GCR_BPS 325

typedef struct transfer_disk_ts_s
{
    uint8_t track;
    uint8_t sector;
}
transfer_disk_ts_t;

typedef struct transfer_disk_status_s
{
    uint8_t             magic;
    uint8_t             status;
    transfer_disk_ts_t  ts;
} transfer_disk_status_t;

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

static void __fastcall__ send_status(uint8_t status,
                                     uint8_t n_track,
                                     uint8_t n_sector)
{
    static transfer_disk_status_t st;

    st.magic = DISK_STATUS_MAGIC;
    st.status = status;
    st.ts.track = n_track;
    st.ts.sector = n_sector;

    ef3usb_send_data(&st, sizeof(st));
}


/******************************************************************************/
/**
 * Write a d64 image to disk.
 *
 * The main program got the start command over USB already.
 */
void write_disk_d64(void)
{
    static transfer_disk_ts_t ts;
    static transfer_disk_ts_t prev_ts;
    static uint8_t a_sector_data[GCR_BPS];
    uint8_t rv, b_first_sector;
    int i;

    puts("\nd64 writer started");
    ef3usb_send_str("load");

    if (init_eload(8) == 0)
    {
        ef3usb_fclose();
        puts("exit");
        return;
    }

    printf("Preparing drive... ");
    eload_prepare_drive();
    puts("ok");

    /* Send initial "OK" */
    send_status(DISK_STATUS_OK, 0, 0);

    // disable VIC-II DMA
    VIC.ctrl1 &= 0xef;
    while (VIC.rasterline != 255)
    {}

    /* download current sector while previous sector is being written to disk */
    b_first_sector = 1;
    do
    {
        /* Receive sector */
        ef3usb_receive_data(&ts, sizeof(ts));
        if (ts.track != 0) /* track == 0 => end */
        {
            ef3usb_receive_data(a_sector_data, GCR_BPS);
        }

        /* Send status for last sector written, if any */
        if (!b_first_sector)
        {
            rv = eload_recv_status();
            /* todo: unify status codes */
            send_status(DISK_STATUS_OK, prev_ts.track, prev_ts.sector);
        }
        b_first_sector = 0;

        /* Write sector, if any */
        if (ts.track)
        {
            eload_write_sector_nodma((ts.track << 8) | ts.sector, a_sector_data);
        }
        prev_ts = ts;
    }
    while (prev_ts.track);

    eload_close();
    puts("Disk written\n\n");

    // enable VIC-II DMA
    VIC.ctrl1 |= 0x10;
}
