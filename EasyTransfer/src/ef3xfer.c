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

#include <ftdi.h>
#include "ef3xfer.h"

static struct ftdi_context m_ftdic;

static void log_ftdi_error(int reason);
static void log_printf(const char* p_str_format, ...);
static int connect_ftdi(void);
static int read_from_ftdi(unsigned char* p_buffer, int size);
static int write_to_ftdi(unsigned char* p_buffer, int size);
static int start_handshake(void);
static void send_command(const char* p_str_request);
static void receive_response(unsigned char* p_resp, int size_resp,
                             int timeout_secs);
static int send_file(const char* p_str_filename);

/* function pointers which can be overridden from external apps */
static void (*log_str)(const char* str);
static void (*log_complete)(void);
static void (*log_progress)(int percent);


/*****************************************************************************/
void ef3xfer_set_callbacks(
        void (*custom_log_str)(const char* str),
        void (*custom_log_progress)(int percent),
        void (*custom_log_complete)(void))
{
    log_str      = custom_log_str;
    log_progress = custom_log_progress;
    log_complete = custom_log_complete;
}

/*****************************************************************************/
void ef3xfer_transfer(const char* p_str_filename)
{
    uint16_t      crc;
    size_t        i, size;
    uint8_t*      p;

    log_printf("Input:  %s\n", p_str_filename);

    if (!connect_ftdi())
        return;

    if (!start_handshake())
        return;

    if (!send_file(p_str_filename))
        return;

    log_printf("\n\\o/\nREADY.\n\n");
    log_complete();
}


/*****************************************************************************/
/*
 */
static void log_ftdi_error(int reason)
{
    const char* p_str_cause;

    if (reason < 0)
        p_str_cause = strerror(-reason);
    else
        p_str_cause = "unknown cause";

    log_printf("USB operation failed: %d (%s - %s)\n", reason,
            ftdi_get_error_string(&m_ftdic),
            p_str_cause);
}


/*****************************************************************************/
/**
 *
 */
static void log_printf(const char* p_str_format, ...)
{
    va_list args;
    char str[200];

    va_start(args, p_str_format);
    vsnprintf(str, sizeof(str) - 1, p_str_format, args);
    va_end(args);

    str[sizeof(str) - 1] = '\0';
    log_str(str);
}


/*****************************************************************************/
/**
 *
 */
static int connect_ftdi(void)
{
    int ret;

    if (ftdi_init(&m_ftdic) < 0)
    {
        log_printf("Failed to initialize FTDI library\n");
        return 0;
    }

    if ((ret = ftdi_usb_open(&m_ftdic, 0x0403, 0x8738)) < 0)
    {
        log_printf("Unable to open ftdi device: %d (%s)\n", ret,
                ftdi_get_error_string(&m_ftdic));
        return 0;
    }

    ftdi_usb_reset(&m_ftdic);
    ftdi_usb_purge_buffers(&m_ftdic);

    return 1;
}


/*****************************************************************************/
/**
 * Read the given number of bytes from USB. Do not return before the whole
 * number of bytes has been received.
 *
 * Return size on success, 0 otherwise.
 */
static int read_from_ftdi(unsigned char* p_buffer, int size)
{
    int n_read, ret;

    n_read = 0;
    do
    {
        ret = ftdi_read_data(&m_ftdic, p_buffer + n_read, size - n_read);

        if (ret < 0)
        {
            log_ftdi_error(ret);
            return 0;
        }

        if (ret == 0)
            {} // wxMilliSleep(50); // <= todo

        n_read += ret;
    }
    while (n_read < size);

    return n_read;
}


/*****************************************************************************/
/**
 * Write the given number of bytes from USB. Do not return before the whole
 * number of bytes has been written or an error occured.
 *
 * Return size on success, 0 otherwise.
 */
static int write_to_ftdi(unsigned char* p_buffer, int size)
{
    int block_size;
    int n_written, ret;

    n_written = 0;
    while (n_written < size)
    {
        if (size - n_written > 128)
            block_size = 128;
        else
            block_size = size - n_written;

        ret = ftdi_write_data(&m_ftdic, p_buffer + n_written, block_size);

        if (ret < 0)
        {
            log_ftdi_error(ret);
            return 0;
        }

        n_written += ret;
    }

    return n_written;
}


/*****************************************************************************/
/**
 *
 */
static int start_handshake(void)
{
    int waiting;
    unsigned char str_response[20];

    /* Send the command as often as we get "WAIT" as response */
    do
    {
        waiting = 0;
        send_command("EFSTART:CRT");
        receive_response(str_response, sizeof(str_response), 20);

        if (str_response[0] == 0)
            return 0;

        if (strcmp((char*)str_response, "WAIT") == 0)
        {
            log_printf("Waiting...\n");
            waiting = 1;
        }
    }
    while (waiting);

    log_printf("Running...\n");

    if (strcmp((char*)str_response, "BTYP") == 0)
    {
        log_printf("(%s) Client doesn't support this file type or action.\n", str_response);
        return 0;
    }
    else if (strcmp((char*)str_response, "LOAD") == 0)
    {
        log_printf("(%s) Start to send data.\n", str_response);
        return 1;
    }
    else
    {
        log_printf("Unknown response: \"%s\"\n", str_response);
        return 0;
    }


    return 0;
}


/*****************************************************************************/
/**
 *
 */
static void send_command(const char* p_str_request)
{
    int           ret;
    unsigned char str_response[8];
    size_t        size_request;

    size_request = strlen(p_str_request);

    log_printf("Send command: %s\n", p_str_request);
    // Send request
    ret = ftdi_write_data(&m_ftdic, (unsigned char*)p_str_request,
                          size_request);

    if (ret != size_request)
    {
        log_printf("Write failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                ret < 0 ? strerror(-ret) : "unknown cause");
    }
}


/*****************************************************************************/
/**
 * Try to receive a response. Return the response (0-terminated) or an empty
 * string of there was no response.
 */
static void receive_response(unsigned char* p_resp, int size_resp,
                             int timeout_secs)
{
    int  ret, retry, i;

    retry = timeout_secs;
    do
    {
        sleep(1); // todo: schoener machen
        p_resp[0] = '\0';
        ret = ftdi_read_data(&m_ftdic, p_resp, size_resp - 1);
        if (ret < 0)
        {
            p_resp[0] = 0;
            log_printf("Read failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                    ret < 0 ? strerror(-ret) : "unknown cause");
            return;
        }
        else if (ret > 0)
        {
            p_resp[ret] = 0;
            log_printf("Got response: \"%s\".\n", (char*) p_resp);
            return;
        }
    }
    while (ret == 0 && --retry);

    log_printf("Time out.\n", ret, retry);
    p_resp[0] = 0;
}


/*****************************************************************************/
/**
 *
 */
static int send_file(const char* p_str_filename)
{
    static unsigned char a_buffer[0x10000]; /* <= yay! */
    unsigned char a_buffer_size[2];
    int           n_bytes_req;
    FILE*         fp;
    long          size_file;
    int           ret, count, rest;

    fp = fopen(p_str_filename, "rb");
    if (fp == NULL)
    {
        log_printf("Error: Cannot open %s for reading\n", p_str_filename);
        return 0;
    }
    /* todo: use fstat */
    fseek(fp, 0, SEEK_END);
    size_file = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    do
    {
        /* read the number of bytes requested by the client (0..256) */
        if (!read_from_ftdi(a_buffer_size, 2))
        {
            fclose(fp);
            return 0;
        }
        n_bytes_req = a_buffer_size[0] + a_buffer_size[1] * 256;

        if (n_bytes_req > 0)
        {
            if (feof(fp))
                count = 0;
            else
                count = fread(a_buffer, 1, n_bytes_req, fp);

            // todo: error checks

            a_buffer_size[0] = count & 0xff;
            a_buffer_size[1] = count >> 8;
            // send length indication
            ret = write_to_ftdi(a_buffer_size, 2);
            if (ret != 2)
            {
                fclose(fp);
                return 0;
            }
            // send payload
            ret = write_to_ftdi(a_buffer, count);
            if (ret != count)
            {
                fclose(fp);
                return 0;
            }
        }
        // todo: check overhead
        log_progress((int)(100 * (ftell(fp) + 1) / size_file));
    }
    while (n_bytes_req > 0);

    fclose(fp);
    return 1;
}
