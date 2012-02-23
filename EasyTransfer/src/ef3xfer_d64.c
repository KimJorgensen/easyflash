

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
#define D64_SIZE_40_TRACKS 196608

#define D64_BUFFER_SIZE (D64_SIZE_40_TRACKS + 1)

#define GCR_BPS 325

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
    union
    {
        transfer_disk_ts_t  ts;
        uint16_t            data16;
    } data;
} transfer_disk_status_t;

static const uint8_t a_sectors_per_track[D64_MAX_TRACKS] =
{
        21, 21, 21, 21, 21,   21, 21, 21, 21, 21,     /*  1 .. 10 */
        21, 21, 21, 21, 21,   21, 21, 19, 19, 19,     /* 11 .. 20 */
        19, 19, 19, 19, 18,   18, 18, 18, 18, 18,     /* 21 .. 30 */
        17, 17, 17, 17, 17,   17, 17, 17, 17, 17      /* 31 .. 40 */
};

static const uint16_t a_track_offset_in_d64[D64_MAX_TRACKS] =
{
          0,  21,  42,  63,  84,    105, 126, 147, 168, 189, /*  1 .. 10 */
        210, 231, 252, 273, 294,    315, 336, 357, 376, 395, /* 11 .. 20 */
        414, 433, 452, 471, 490,    508, 526, 544, 562, 580, /* 21 .. 30 */
        598, 615, 632, 649, 666,    683, 700, 717, 734, 751  /* 31 .. 40 */
};

/* Conversion BIN => GCR */
static const uint8_t bin_to_gcr[16] =
{
    0x0a, 0x0b, 0x12, 0x13,
    0x0e, 0x0f, 0x16, 0x17,
    0x09, 0x19, 0x1a, 0x1b,
    0x0d, 0x1d, 0x1e, 0x15
};


/*****************************************************************************/
/**
 * Convert 4 bytes of binary data from src to 5 bytes of GCR data to dst.
 */
static void drive_gcr_encode(uint8_t* dst, const uint8_t* src)
{
    uint32_t o, i;

    // aaaa bbbb => oo ooop pppp
    i  = src[0];
    o  = bin_to_gcr[i >> 4] << 5;
    o |= bin_to_gcr[i & 0xf];
    dst[0] = o >> 2;
    o <<= 10;
    // cccc dddd => ppqq qqqr rrrr
    i  = src[1];
    o |= bin_to_gcr[i >> 4] << 5;
    o |= bin_to_gcr[i & 0xf];
    dst[1] = o >> 4;
    o <<= 10;
    // eeee ffff => rr rrss ssst tttt
    i  = src[2];
    o |= bin_to_gcr[i >> 4] << 5;
    o |= bin_to_gcr[i & 0xf];
    dst[2] = o >> 6;
    o <<= 10;
    // gggg hhhh => sttt ttuu uuuv vvvv
    i  = src[3];
    o |= bin_to_gcr[i >> 4] << 5;
    o |= bin_to_gcr[i & 0xf];
    dst[3] = o >> 8;
    dst[4] = o;
}


/*****************************************************************************/
/**
 * Calculate and return an EOR checksum of the given data.
 *
 */
static unsigned drive_checksum(const uint8_t* p_data, unsigned len)
{
    unsigned i, sum;
    sum = 0;
    for (i = 0; i < len; ++i)
    {
        sum ^= p_data[i];
    }
    return sum;
}


/*****************************************************************************/
/**
 * Convert a binary sector of 256 bytes to a GCR encoded sector.
 *
 * dst          Target for encoded sector data
 * src          binary sector data, 256 bytes
 * track        track number, 0-based
 * sector       sector
 */
void encode_sector_to_gcr(uint8_t* p_dst,
                          const uint8_t* p_src)
{
    unsigned n_in, n_out;
    uint8_t bin[8];

    n_in = 0;
    n_out = 0;
#if 0
    // create header sync
    memset(p_dst, 0xff, SECTOR_LEN_HEADER_SYNC);
    p_dst += SECTOR_LEN_HEADER_SYNC;

    // create header
    bin[0] = 0x08; // header
    bin[2] = n_sector;
    bin[3] = n_track + 1;
    bin[4] = 0x58; // id 2
    bin[5] = 0x5a; // id 1
    bin[6] = 0x0f; // off byte
    bin[7] = 0x0f; // off byte
    bin[1] = drive_checksum(bin + 2, 4);
    drive_gcr_encode(p_dst, bin);
    p_dst += 5;
    drive_gcr_encode(p_dst, bin + 4);
    p_dst += 5;

    // create header gap
    memset(p_dst, 0x55, SECTOR_LEN_HEADER_GAP);
    p_dst += SECTOR_LEN_HEADER_GAP;

    // create data sync
    memset(p_dst, 0xff, SECTOR_LEN_DATA_SYNC);
    p_dst += SECTOR_LEN_DATA_SYNC;
#endif

    // first 3 bytes of src data come to this GCR block
    bin[0] = 0x07;    // $00 - data block ID
    bin[1] = p_src[n_in++];
    bin[2] = p_src[n_in++];
    bin[3] = p_src[n_in++];
    drive_gcr_encode(p_dst + n_out, bin);
    n_out += 5;

    // 253 bytes left, convert next 63 * 4 = 252 bytes => up to byte 0xff
    while (n_in < 0xff)
    {
        drive_gcr_encode(p_dst + n_out, p_src + n_in);
        n_in += 4;
        n_out += 5;
    }

    // last data byte goes to this GCR-block
    bin[0] = p_src[n_in];
    bin[1] = drive_checksum(p_src, 256);
    bin[2] = 0;
    bin[3] = 0;
    drive_gcr_encode(p_dst + n_out, bin);
    n_out += 5;

#if 0
    // create tail gap
    memset(p_dst, 0xff, SECTOR_LEN_TAIL_GAP);
    p_dst += SECTOR_LEN_TAIL_GAP;
#endif
}


/*****************************************************************************/
/**
 *
 */
static int check_c64_response(transfer_disk_status_t* p_st)
{

    /* read the status from C-64 */
    if (!ef3xfer_read_from_ftdi(p_st, sizeof(*p_st)))
    {
        return 0;
    }

    if (p_st->magic == 0)
    {
        ef3xfer_log_printf("\nClose request received.\n");
        return 0;
    }

    if (p_st->magic != DISK_STATUS_MAGIC)
    {
        ef3xfer_log_printf("\nInvalid data from C-64.\n");
        return 0;
    }

    if (p_st->status != DISK_STATUS_OK)
    {
        ef3xfer_log_printf("\nError %d at track %d, sector %d.\n",
                           p_st->status,
                           p_st->data.ts.track,
                           p_st->data.ts.sector);
        return 0;
    }

    return 1;
}

/*****************************************************************************/
/**
 *
 */
static int send_d64(uint8_t* p_buffer,
                    uint8_t* p_gcr_buffer,
                    int n_num_tracks)
{
    transfer_disk_status_t st;
    transfer_disk_ts_t ts;
    uint8_t gcr[GCR_BPS];
    uint8_t a_sector_state[D64_MAX_SECTORS];
    long    offset;
    int     n_sectors_left, n_sectors, n_interleave, i;
    int     b_first_sector;

    n_interleave = 4;
    b_first_sector = 1;
    for (ts.track = 1; ts.track <= n_num_tracks; ++ts.track)
    {
        ef3xfer_log_printf("Track %2d", ts.track);

        n_sectors_left = a_sectors_per_track[ts.track - 1];
        n_sectors = n_sectors_left;

        /* Send sectors, one by one */
        memset(a_sector_state, 0, sizeof(a_sector_state));
        ts.sector = 0;
        while (n_sectors_left)
        {
            /* Search next untransferred sector */
            ts.sector = (ts.sector + n_interleave) % n_sectors;
            while (a_sector_state[ts.sector])
                ts.sector = (ts.sector + 1) % n_sectors;

            offset = (a_track_offset_in_d64[ts.track - 1] + ts.sector) * 256;

            encode_sector_to_gcr(p_gcr_buffer, p_buffer + offset);

            /* Send track and sector numbers */
            if (!ef3xfer_write_to_ftdi(&ts, sizeof(ts)))
                return 0;

            if (!ef3xfer_write_to_ftdi(p_gcr_buffer, GCR_BPS))
                return 0;

            ef3xfer_log_printf(".");

            /* no response after the 1st sector has been sent */
            if (!b_first_sector)
                if (!check_c64_response(&st))
                    return 0;
            b_first_sector = 0;

            a_sector_state[ts.sector] = 1;
            --n_sectors_left;
        }
        ef3xfer_log_printf("\n");
    }

    /* track == 0 => end mark */
    ts.track = 0;
    if (!ef3xfer_write_to_ftdi(&ts, sizeof(ts)))
        return 0;

    /* this is the response for the last sector written */
    return check_c64_response(&st);
}


/*****************************************************************************/
/**
 *
 */
int ef3xfer_d64_write(const char* p_filename, int do_format)
{
    transfer_disk_status_t st;
    uint8_t     options[4];
    uint8_t*    p_buffer = NULL;
    uint8_t*    p_gcr_buffer = NULL;
    int         n_tracks;
    long        file_size;
    int         ret = 0; // <= error
    FILE*       fp = NULL;

    p_buffer = malloc(D64_BUFFER_SIZE);
    if (!p_buffer)
        goto cleanup_and_ret;

    p_gcr_buffer = malloc(GCR_BPS);
    if (!p_gcr_buffer)
        goto cleanup_and_ret;

    fp = fopen(p_filename, "rb");
    if (fp == NULL)
    {
        ef3xfer_log_printf("Error: Cannot open %s for reading\n", p_filename);
        goto cleanup_and_ret;
    }

    if (!ef3xfer_connect_ftdi())
        goto cleanup_and_ret;

    if (!ef3xfer_do_handshake("D64"))
        goto cleanup_and_ret;

    file_size = fread(p_buffer, 1, D64_BUFFER_SIZE, fp);

    if (file_size == D64_SIZE_35_TRACKS)
        n_tracks = 35;
    else if (file_size == D64_SIZE_40_TRACKS)
        n_tracks = 40;
    else
    {
        ef3xfer_log_printf(
                "Error: Only d64 files with 35 or 40 tracks w/o error info "
                "are supported currently (but I got %d bytes).\n", file_size);
        goto cleanup_and_ret;
    }
    ef3xfer_log_printf("Tracks: %d\n", n_tracks);

    /* options for D64 write = drive number, do_format, n_tracks, 0 */
    memset(options, 0, sizeof(options));
    options[0] = 8; // drive number
    options[1] = do_format ? n_tracks : 0;
    options[2] = rand() % 0xff; /* disk ID */
    options[3] = rand() % 0xff; /* disk ID */
    if (!ef3xfer_write_to_ftdi(options, sizeof(options)))
        goto cleanup_and_ret;

    /* Wait for initial "OK" */
    if (!check_c64_response(&st))
        goto cleanup_and_ret;

    if (do_format)
    {
        ef3xfer_log_printf("Format ok, %d raw bytes on zone 1 (%5f rpm)\n",
                st.data.data16,
                (double)st.data.data16 / 7692.0 * 300.0);
    }

    ret = send_d64(p_buffer, p_gcr_buffer, n_tracks);

cleanup_and_ret:
    if (fp)
        fclose(fp);
    if (p_buffer)
        free(p_buffer);
    if (p_gcr_buffer)
        free(p_gcr_buffer);

    return ret;
}
