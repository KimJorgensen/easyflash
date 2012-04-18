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
#include <unistd.h>

#include <ftdi.h>

#include "ef3xfer.h"
#include "ef3xfer_internal.h"
#include "str_to_key.h"

static struct ftdi_context m_ftdic;

static void send_command(const char* p_str_request);
static void receive_response(unsigned char* p_resp,
                             int timeout_secs);
static int send_file(FILE* fp);

/* function pointers which can be overridden from external apps */
static void (*log_str)(const char* str);
static void (*log_complete)(void);
static void (*log_progress)(int percent);
static void ef3xfer_msleep(unsigned msecs);

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
int ef3xfer_transfer_keys(const char* keys)
{
    int     len, i, ret, subst_len;
    char    key;
    const str_to_key_t* p_tab;

    if (keys == NULL)
    {
        ef3xfer_log_printf("Missing keys to be sent.\n");
        return 0;
    }

    len = strlen(keys);

    if (!ef3xfer_connect_ftdi())
        return 0;

    i = 0;
    while (i < len)
    {
        if (!ef3xfer_do_handshake("KEY"))
            return 0;

        // check for entities which must be replaced by single keys
        key = 0;
        p_tab = str_to_key;
        while (p_tab->str)
        {
            subst_len = strlen(p_tab->str);
            if (strncmp(p_tab->str, keys + i, subst_len) == 0)
            {
                key = p_tab->key;
                i += subst_len;
                break;
            }
            p_tab++;
        }
        if (key == 0)
        {
            key = keys[i++];
            /* code conversion */
            if (key >= 'A' && key <= 'Z')
                key = 193 + key - 'A';
            else if (key >= 'a' && key <= 'z')
                key = 65 + key - 'a';
        }

        ret = ef3xfer_write_to_ftdi(&key, 1);
        if (ret != 1)
            return 0;
    }

    ef3xfer_log_printf("\nOK\n\n");
    return 1;
}

/*****************************************************************************/
int ef3xfer_transfer_prg(const char* p_filename, int b_exec)
{
    FILE*         fp;
    uint16_t      crc;
    size_t        i, size;
    uint8_t*      p;
    uint8_t       start[2];

    if (p_filename == NULL)
    {
        ef3xfer_log_printf("Missing file name.\n");
        return 0;
    }

    ef3xfer_log_printf("Send PRG file:  %s\n", p_filename);

    fp = fopen(p_filename, "rb");
    if (fp == NULL)
    {
        ef3xfer_log_printf("Error: Cannot open %s for reading\n", p_filename);
        return 0;
    }
    if (b_exec)
    {
        if (fread(start, 2, 1, fp) != 1)
            goto close_and_err;
        fseek(fp, 0, SEEK_SET);
    }

    if (!ef3xfer_connect_ftdi())
        goto close_and_err;

    if (!ef3xfer_do_handshake("PRG"))
        goto close_and_err;

    if (!send_file(fp))
        goto close_and_err;

    fclose(fp);
    ef3xfer_log_printf("\nOK\n\n");

    if (b_exec)
    {
        if (start[0] == 0x01 && start[1] == 0x08)
            return ef3xfer_transfer_keys("<SHIFT-RETURN>run:<RETURN>");
        else
            return ef3xfer_transfer_sys(start[1] * 256 + start[0]);
    }
    return 1;

close_and_err:
    fclose(fp);
    return 0;
}

/*****************************************************************************/
int ef3xfer_transfer_sys(unsigned addr)
{
    char str[40];
    sprintf(str, "<SHIFT-RETURN>sys%u:<RETURN>", addr);
    return ef3xfer_transfer_keys(str);
}


/*****************************************************************************/
/*
 */
void ef3xfer_log_ftdi_error(int reason)
{
    const char* p_str_cause;

    if (reason < 0)
        p_str_cause = strerror(-reason);
    else
        p_str_cause = "unknown cause";

    ef3xfer_log_printf("USB operation failed: %d (%s - %s)\n", reason,
            ftdi_get_error_string(&m_ftdic),
            p_str_cause);
}


/*****************************************************************************/
/**
 *
 */
void ef3xfer_log_printf(const char* p_str_format, ...)
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
int ef3xfer_connect_ftdi(void)
{
    int ret;

    if (ftdi_init(&m_ftdic) < 0)
    {
        ef3xfer_log_printf("Failed to initialize FTDI library\n");
        return 0;
    }

    if ((ret = ftdi_usb_open(&m_ftdic, 0x0403, 0x8738)) < 0)
    {
        ef3xfer_log_printf("Unable to open ftdi device: %d (%s)\n", ret,
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
int ef3xfer_read_from_ftdi(void* p_buffer, int size)
{
    unsigned char* p = p_buffer;
    int n_read, ret;

    n_read = 0;
    do
    {
        ret = ftdi_read_data(&m_ftdic, p + n_read, size - n_read);

        if (ret < 0)
        {
            ef3xfer_log_ftdi_error(ret);
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
 * number of bytes has been written or an error occurred.
 *
 * Return size on success, 0 otherwise.
 */
int ef3xfer_write_to_ftdi(const void* p_buffer, int size)
{
    unsigned char* p = (unsigned char*) p_buffer; /* <= meh */
    int block_size;
    int n_written, ret;

    n_written = 0;
    while (n_written < size)
    {
        if (size - n_written > 128)
            block_size = 128;
        else
            block_size = size - n_written;

        ret = ftdi_write_data(&m_ftdic, p + n_written, block_size);

        if (ret < 0)
        {
            ef3xfer_log_ftdi_error(ret);
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
int ef3xfer_do_handshake(const char* p_str_type)
{
    int waiting;
    char          str_command[20];
    unsigned char str_response[EF3XFER_RESP_SIZE + 1];

    if (strlen(p_str_type) != 3)
    {
        ef3xfer_log_printf("Error: Bad type \"%s\"\n", p_str_type);
        return 0;
    }

    strcpy(str_command, "EFSTART:");
    strcat(str_command, p_str_type);
    /* Send the command as often as we get "WAIT" as response */
    do
    {
        waiting = 0;
        send_command(str_command);
        receive_response(str_response, 30);

        if (str_response[0] == 0)
            return 0;

        if (strcmp((char*)str_response, "WAIT") == 0)
        {
            ef3xfer_log_printf("Waiting...\n");
            waiting = 1;
        }
    }
    while (waiting);

    ef3xfer_log_printf("Running...\n");

    if (strcmp((char*)str_response, "ETYP") == 0)
    {
        ef3xfer_log_printf("(%s) Client doesn't support this file type or action.\n", str_response);
        return 0;
    }
    else if (strcmp((char*)str_response, "LOAD") == 0)
    {
        ef3xfer_log_printf("(%s) Start to send data.\n", str_response);
        return 1;
    }
    else
    {
        ef3xfer_log_printf("Unknown response: \"%s\"\n", str_response);
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

    size_request = strlen(p_str_request) + 1;

    ef3xfer_log_printf("Send command: %s\n", p_str_request);
    // Send request
    ret = ftdi_write_data(&m_ftdic, (unsigned char*)p_str_request,
                          size_request);

    if (ret != size_request)
    {
        ef3xfer_log_printf("Write failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                ret < 0 ? strerror(-ret) : "unknown cause");
    }
}


/*****************************************************************************/
/**
 * Try to receive a response. Return the response (0-terminated) or an empty
 * string of there was no response.
 */
static void receive_response(unsigned char* p_resp,
                             int timeout_secs)
{
    int  ret, retry, i;

    retry = timeout_secs * 100;
    do
    {
        ef3xfer_msleep(10);
        ret = ef3xfer_read_from_ftdi(p_resp, EF3XFER_RESP_SIZE);
        if (ret)
        {
            p_resp[ret] = 0;
            ef3xfer_log_printf("Got response: \"%s\".\n", (char*) p_resp);
            return;
        }
    }
    while (ret == 0 && --retry);

    ef3xfer_log_printf("Time out.\n", ret, retry);
    p_resp[0] = 0;
}


/*****************************************************************************/
/**
 *
 */
static int send_file(FILE* fp)
{
    static unsigned char a_buffer[0x10000]; /* <= yay! */
    unsigned char a_buffer_size[2];
    int           n_bytes_req;
    long          size_file;
    int           ret, count, rest;

    /* todo: use fstat */
    fseek(fp, 0, SEEK_END);
    size_file = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    do
    {
        /* read the number of bytes requested by the client (0..256) */
        if (!ef3xfer_read_from_ftdi(a_buffer_size, 2))
        {
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
            ret = ef3xfer_write_to_ftdi(a_buffer_size, 2);
            if (ret != 2)
            {
                return 0;
            }
            // send payload
            ret = ef3xfer_write_to_ftdi(a_buffer, count);
            if (ret != count)
            {
                return 0;
            }
        }
        // todo: check overhead
        log_progress((int)(100 * (ftell(fp) + 1) / size_file));
    }
    while (n_bytes_req > 0);

    return 1;
}

/*****************************************************************************/
/**
 *
 */
static void ef3xfer_msleep(unsigned msecs)
{
    usleep(1000 * msecs);
}

