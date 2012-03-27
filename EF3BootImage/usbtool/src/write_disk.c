
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <c64.h>

#include <ef3usb.h>
#include <eload.h>

#include "usbtool.h"

/* buffers used in this module */
static uint8_t options[4];
static uint8_t status[3];


#define DISK_STATUS_MAGIC            0x52

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

    ef3usb_receive_data(options, sizeof(options));
    printf("Options: %02x %02x %02x %02x\n",
            options[0], options[1], options[2], options[3]);

    if (init_eload(options[0]) == 0)
    {
        ef3usb_fclose();
        puts("exit");
        return;
    }

    printf("Preparing drive... ");
    eload_prepare_drive();
    puts("ok");

    if (options[1]) /* Number of tracks to be formatted */
    {
        eload_format(options[1], (options[2] | options[3] << 8));
        puts("formatting... ");
        eload_recv_status(status);
        printf("result: %d, %d\n", status[0], status[1] | (status[2] << 8));

        /* Send status and bytes per track */
        send_status(status[0], status[1], status[2]);
    }
    else
    {
        /* Send initial "OK" */
        send_status(DISK_STATUS_OK, 0, 0);
    }

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
            eload_recv_status(status);
            send_status(status[0], prev_ts.track, prev_ts.sector);
            if (status[0] != DISK_STATUS_OK)
                break;
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
    if (rv == DISK_STATUS_OK)
        puts("Disk written\n\n");
    else
        printf("Error %d at %d:%d\n\n", rv, prev_ts.track, prev_ts.sector);

    // enable VIC-II DMA
    VIC.ctrl1 |= 0x10;
}
