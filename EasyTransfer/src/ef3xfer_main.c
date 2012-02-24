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
static const char* guess_type(const char* p_filename);
static void log_str_stdout(const char* str);
static void log_progress_stdout(int percent);
static void log_complete_stdout(void);


/*****************************************************************************/
int main(int argc, char** argv)
{
    const char* p_str_type = NULL;
    const char* p_filename = NULL;
    int i;
    int do_format = 0;


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
        else if (strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--crt") == 0)
        {
            p_str_type = "CRT";
        }
        else if (strcmp(argv[i], "-p") == 0 || strcmp(argv[i], "--prg") == 0)
        {
            p_str_type = "PRG";
        }
        else if (strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--write-disk") == 0)
        {
            p_str_type = "D64";
        }
        else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--format") == 0)
        {
            do_format = 1;
        }
        else if (argv[i][0] == '-')
        {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            return 1;
        }
        else if (p_filename == NULL)
            p_filename = argv[i];
        else
        {
            fprintf(stderr, "Too many arguments: %s\n", argv[i]);
            return 1;
        }
    }
    if (p_filename == NULL)
    {
        fprintf(stderr, "Error: No file name\n");
        return 1;
    }

    if (p_str_type == NULL)
    {
        p_str_type = guess_type(p_filename);
    }
    if (p_str_type == NULL)
    {
        fprintf(stderr,
                "Error: File type not specified and not recognized.\n");
        return 1;
    }

    if (strcmp(p_str_type, "D64") == 0)
    {
        ef3xfer_d64_write(p_filename, do_format);
    }
    else
    {
        ef3xfer_transfer(p_filename, p_str_type);
    }
}


/*****************************************************************************/
static void usage(const char* p_str_prg)
{
    printf("\n"
           "ef3xfer version %s\n\n", VERSION);
    printf("Transfer a file to an EasyFlash 3 over USB.\n\n");
    printf("Usage: %s [options] filename\n", p_str_prg);
    printf("Options:\n"
           "  -h, --help        print this and exit\n"
           "  -c  --crt         flash a cartridge image\n"
           "  -p  --prg         start a program file\n"
           "  -w  --write-disk  write a disk image (d64)\n"
           "\nIf no option is given, the program type is guessed from "
           "the file name suffix.\n"
           "\nOptions to be used with --write-disk:\n"
           "  -f  --format      format disk before write\n"
           "\n"
          );
}


/*****************************************************************************/
static const char* guess_type(const char* p_filename)
{
    const char* p_suffix;
    int len;

    len = strlen(p_filename);
    if (len < 4)
        return NULL;

    len -= 4;
    p_suffix = p_filename + len;

    if (strcasecmp(p_suffix, ".crt") == 0)
        return "CRT";

    if (strcasecmp(p_suffix, ".prg") == 0)
        return "PRG";

    if (strcasecmp(p_suffix, ".d64") == 0)
        return "D64";

    return NULL;
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
