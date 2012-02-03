

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include <ftdi.h>

#include "ef3xfer.h"
#include "ef3xfer_internal.h"

#define D64_MAX_TRACKS  40 /* 1..40 */
#define D64_MAX_SECTORS 21 /* 0..20 */

#define D64_SIZE_35_TRACKS 174848

#define D64_BUFFER_SIZE (D64_SIZE_35_TRACKS + 1)

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


uint8_t a_sectors_per_track[D64_MAX_TRACKS] =
{
        21, 21, 21, 21, 21,   21, 21, 21, 21, 21,     /*  1 .. 10 */
        21, 21, 21, 21, 21,   21, 21, 19, 19, 19,     /* 11 .. 20 */
        19, 19, 19, 19, 18,   18, 18, 18, 18, 18,     /* 21 .. 30 */
        17, 17, 17, 17, 17,   17, 17, 17, 17, 17      /* 31 .. 40 */
};

uint16_t a_track_offset_in_d64[D64_MAX_TRACKS] =
{
          0,  21,  42,  63,  84,    105, 126, 147, 168, 189, /*  1 .. 10 */
        210, 231, 252, 273, 294,    315, 336, 357, 376, 395, /* 11 .. 20 */
        414, 433, 452, 471, 490,    508, 526, 544, 562, 580, /* 21 .. 30 */
        598, 615, 632, 649, 666,    683, 700, 717, 734, 751  /* 31 .. 40 */
};



/*****************************************************************************/
/**
 *
 */
static int check_c64_response(void)
{
    uint8_t a_from_c64[2];

    /* read the status from C-64 */
    if (!ef3xfer_read_from_ftdi(a_from_c64, 2))
    {
        return 0;
    }

    if (a_from_c64[0] == 0)
    {
        ef3xfer_log_printf("Close request received.\n");
        return 0;
    }

    if (a_from_c64[0] != DISK_STATUS_MAGIC)
    {
        ef3xfer_log_printf("Invalid data from C-64.\n");
        return 0;
    }

    if (a_from_c64[0] == DISK_STATUS_MAGIC &&
        a_from_c64[1] != DISK_STATUS_OK)
    {
        ef3xfer_log_printf("C-64 reported error code $%02X.\n",
                           a_from_c64[1]);
        return 0;
    }

    return 1;
}

/*****************************************************************************/
/**
 *
 */
static int send_d64(uint8_t* p_buffer, int n_num_tracks)
{
    uint8_t a_ts[2 + 22];
    uint8_t a_sector_state[D64_MAX_SECTORS];
    long    offset;
    int     n_sectors_left, n_spt, n_interleave, i;
    int     n_track;            /* <= one-based */
    int     n_sector;           /* <= zero-based */


    n_interleave = 8;

    for (n_track = 1; n_track <= n_num_tracks; ++n_track)
    {
        ef3xfer_log_printf("Track %2d\n", n_track);

        n_sectors_left = a_sectors_per_track[n_track - 1];
        n_spt = n_sectors_left;

        a_ts[0] = n_track;
        a_ts[1] = n_sectors_left;

        /* build sector order table */
        memset(a_sector_state, 0, sizeof(a_sector_state));
        n_sector = 0;
        i = 2;
        while (n_sectors_left)
        {
            n_sector = (n_sector + n_interleave) % n_spt;
            while (a_sector_state[n_sector])
                n_sector = (n_sector + 1) % n_spt;

            a_sector_state[n_sector] = 1;
            a_ts[i++] = n_sector;

            --n_sectors_left;
        }
        a_ts[i] = 0xff; // <= end mark


        offset = a_track_offset_in_d64[n_track - 1] * 256;

        if (!check_c64_response())
            return 0;

        if (!ef3xfer_write_to_ftdi(a_ts, sizeof(a_ts)))
            return 0;

        if (!ef3xfer_write_to_ftdi(p_buffer + offset, n_spt * 256))
            return 0;
    }

    memset(a_ts, 0, sizeof(a_ts));
    if (!ef3xfer_write_to_ftdi(a_ts, sizeof(a_ts)))
        return 0;

    return check_c64_response();
}


/*****************************************************************************/
/**
 *
 */
int ef3xfer_d64_write(FILE* fp)
{
    uint8_t*    p_buffer;
    int         n_tracks;
    long        size_file;
    int         ret;

    p_buffer = malloc(D64_BUFFER_SIZE);
    if (!p_buffer)
        return 0;

    size_file = fread(p_buffer, 1, D64_BUFFER_SIZE, fp);

    if (size_file != D64_SIZE_35_TRACKS)
    {
        ef3xfer_log_printf(
                "Error: Only d64 files with 35 tracks are supported "
                "currently.\n");
        free(p_buffer);
        return 0;
    }
    n_tracks = 35;
    ef3xfer_log_printf("Tracks: %d\n", n_tracks);

    ret = send_d64(p_buffer, n_tracks);
    free(p_buffer);

    return ret;
}
