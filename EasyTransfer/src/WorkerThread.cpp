/*
 *
 * (c) 2003-2009 Thomas Giesel
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

#include <wx/wx.h>
#include <wx/file.h>
#include <wx/thread.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdint.h>

#include <ftdi.h>

#include "WorkerThread.h"
#include "EasyTransferMainFrame.h"
#include "EasyTransferApp.h"

/*****************************************************************************/

WorkerThread* WorkerThread::m_pTheWorkerThread;

/*****************************************************************************/
WorkerThread::WorkerThread(wxEvtHandler* pEventHandler,
        const wxString& stringInputFileName) :
    wxThread(wxTHREAD_JOINABLE), m_pEventHandler(pEventHandler),
            m_stringInputFileName(stringInputFileName)
{
    m_pTheWorkerThread = this;
}

/*****************************************************************************/
WorkerThread::~WorkerThread()
{
    m_pTheWorkerThread = NULL;
}

/*****************************************************************************/
void WorkerThread::LogText(const wxString& str)
{
    wxCommandEvent event(wxEVT_EASY_SPLIT_LOG);
    event.SetString(str);
    event.SetInt(0);
    m_pEventHandler->AddPendingEvent(event);
}


/*****************************************************************************/
/*
 * Tell the main thread that we're done.
 */
void WorkerThread::LogComplete(void)
{
    wxCommandEvent event(wxEVT_EASY_SPLIT_LOG);

    event.SetInt(1); // done!

    m_pEventHandler->AddPendingEvent(event);
}


/*****************************************************************************/
void* WorkerThread::Entry()
{
    uint16_t      crc;
    size_t        i, size;
    uint8_t*      p;

    Log("Input:  %s\n",
            (const char*) m_stringInputFileName.mb_str());

    if (!ConnectToEF())
        return NULL;

    if (!StartHandshake())
        return NULL;

    if (!SendFile())
        return NULL;

    Log("\n\\o/\nREADY.\n\n");

    LogComplete();
    return NULL;
}


/*****************************************************************************/
/**
 *
 */
bool WorkerThread::ConnectToEF()
{
    int ret;

    if (ftdi_init(&m_ftdic) < 0)
    {
        Log("Failed to initialize FTDI library\n");
        return false;
    }

    if ((ret = ftdi_usb_open(&m_ftdic, 0x0403, 0x8738)) < 0)
    {
        Log("Unable to open ftdi device: %d (%s)\n", ret, ftdi_get_error_string(&m_ftdic));
        return false;
    }

    ftdi_usb_reset(&m_ftdic);
    ftdi_usb_purge_buffers(&m_ftdic);

    return true;
}



/*****************************************************************************/
/**
 *
 */
bool WorkerThread::StartHandshake()
{
    bool bWaiting;
    unsigned char strResponse[20];

    /* Send the command as often as we get "WAIT" as response */
    do
    {
        bWaiting = false;
        SendCommand("EFSTART:CRT");
        ReceiveResponse(strResponse, sizeof(strResponse), 20);

        if (strResponse[0] == 0)
            return false;

        if (strcmp((char*)strResponse, "WAIT") == 0)
        {
            Log("Waiting...\n");
            bWaiting = true;
        }
    }
    while (bWaiting);

    Log("Running...\n");

    if (strcmp((char*)strResponse, "BTYP") == 0)
    {
        Log("(%s) Client doesn't support this file type or action.\n", strResponse);
        return false;
    }
    else if (strcmp((char*)strResponse, "LOAD") == 0)
    {
        Log("(%s) Start to send data.\n", strResponse);
        return true;
    }
    else
    {
        Log("Unknown response: \"%s\"\n", strResponse);
        return false;
    }


    return false;
}


/*****************************************************************************/
/**
 *
 */
void WorkerThread::SendCommand(const char* pRequestStr)
{
    int         ret;
    unsigned char strResponse[8];
    size_t      nRequestLen;

    nRequestLen = strlen(pRequestStr);

    Log("Send command: %s\n", pRequestStr);
    // Send request
    ret = ftdi_write_data(&m_ftdic, (unsigned char*)pRequestStr, nRequestLen);
    if (ret != nRequestLen)
    {
        Log("Write failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                ret < 0 ? strerror(-ret) : "unknown cause");
    }
}


/*****************************************************************************/
/**
 *
 */
bool WorkerThread::SendFile(void)
{
    uint8_t     buffer[128];
    wxFile*     pFile;
    int         ret, count, rest;

    pFile = new wxFile(m_stringInputFileName, wxFile::read);
    if (!pFile->IsOpened())
    {
        Log("Error: Cannot open %s for reading\n",
                (const char*) m_stringInputFileName.mb_str());
        delete pFile;
        return false;
    }

    do
    {
        count = pFile->Read(buffer, 128);
        rest = count;
        while (rest > 0)
        {
            ret = ftdi_write_data(&m_ftdic, (unsigned char*)buffer, rest);
            if (ret < 0)
            {
                Log("Write failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                        ret < 0 ? strerror(-ret) : "unknown cause");
                delete pFile;
                return false;
            }
            rest -= ret;
        }
    }
    while (count > 0);
    return true;
}


/*****************************************************************************/
/**
 * Try to receive a response. Return the response (0-terminated) or an empty
 * string of there was no response.
 */
void WorkerThread::ReceiveResponse(unsigned char* pResponse,
                                   int sizeResponse,
                                   int timeoutSecs)
{
    int  ret, retry, i;

    /* in 100 ms units */
    retry = timeoutSecs;

    do
    {
        wxMilliSleep(1000);
        pResponse[0] = '\0';
        ret = ftdi_read_data(&m_ftdic, pResponse, sizeResponse - 1);
        if (ret < 0)
        {
            pResponse[0] = 0;
            Log("Read failed: %d (%s - %s)\n", ret, ftdi_get_error_string(&m_ftdic),
                    ret < 0 ? strerror(-ret) : "unknown cause");
            return;
        }
        else if (ret > 0)
        {
            pResponse[ret] = 0;
            Log("Got response: \"%s\".\n", (char*) pResponse);
            return;
        }
    }
    while (ret == 0 && --retry);

    Log("Time out.\n", ret, retry);
    pResponse[0] = 0;
}


/*****************************************************************************/
/**
 *
 */
void WorkerThread::Log(const char* pStrFormat, ...)
{
    va_list args;
    char str[200];

    va_start(args, pStrFormat);
    vsnprintf(str, sizeof(str) - 1, pStrFormat, args);
    va_end(args);

    str[sizeof(str) - 1] = '\0';
    LogText(wxString(str, wxConvUTF8));
}
