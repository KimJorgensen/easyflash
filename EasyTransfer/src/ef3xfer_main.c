/*
 *
 * (c) 2011 Thomas Giesel
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Thomas Giesel skoe@directbox.com
 */

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include "ef3xfer.h"

static void usage(const char* p_str_prg);
static void log_str_stdout(const char* str);
static void log_progress_stdout(int percent);
static void log_complete_stdout(void);


/*****************************************************************************/
int main(int argc, char** argv)
{
    const char* p_str_filename = NULL;
    int i;

    /* default callback functions for stdout */
    ef3xfer_set_callbacks(log_str_stdout, log_progress_stdout,
                          log_complete_stdout);

    for (i = 1; i < argc; ++i)
    {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0)
        {
            usage(argv[0]);
            return 0;
        }
        else if (argv[i][0] == '-')
        {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            return 1;
        }
        else if (p_str_filename == NULL)
            p_str_filename = argv[i];
        else
        {
            fprintf(stderr, "Too many arguments: %s\n", argv[i]);
            return 1;
        }
    }
    if (p_str_filename == NULL)
    {
        fprintf(stderr, "Error: No file name\n");
        return 1;
    }

    ef3xfer_transfer(p_str_filename);
}

/*****************************************************************************/
static void usage(const char* p_str_prg)
{
    printf("\n"
           "ef3xfer version %s\n\n", VERSION);
    printf("Transfer a file to an EasyFlash 3 over USB.\n\n");
    printf("Usage: %s [options] filename\n", p_str_prg);
    printf("Options:\n"
           "  -h, --help     print this and exit\n"
           "\n"
          );
}

/*****************************************************************************/
static void log_str_stdout(const char* str)
{
    printf("%s", str);
    fflush(stdout);
}


/*****************************************************************************/
/*
 */
static void log_progress_stdout(int percent)
{
    if (percent < 0)
        percent = 0;
    if (percent > 100)
        percent = 100;

    printf("\r%3d%%", percent);
    fflush(stdout);
}


/*****************************************************************************/
/*
 * Tell the main thread that we're done.
 */
static void log_complete_stdout(void)
{
}
