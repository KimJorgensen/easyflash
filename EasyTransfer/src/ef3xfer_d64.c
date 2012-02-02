

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include <ftdi.h>

#include "ef3xfer.h"
#include "ef3xfer_internal.h"

#define D64_SIZE_35_TRACKS 174848

#define D64_BUFFER_SIZE (D64_SIZE_35_TRACKS + 1)

/*****************************************************************************/
/**
 *
 */
int ef3xfer_d64_write(FILE* fp)
{
    uint8_t*    p_buffer;
    uint8_t     a_from_c64[2];
    uint8_t     n_tracks;
    long        size_file;
    int         ret, count, rest;

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

    for (;;)
    {
        /* read the status from C64 */
        if (!ef3xfer_read_from_ftdi(a_from_c64, 2))
        {
            free(p_buffer);
            return 0;
        }

        if (a_from_c64[0] == 0)
        {
            ef3xfer_log_printf("Close request received.\n");
            free(p_buffer);
            return 0;
        }
    }

    return 1;
}
