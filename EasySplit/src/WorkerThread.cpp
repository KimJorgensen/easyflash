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
#include <wx/ffile.h>
#include <wx/thread.h>
#include <stdarg.h>
#include <stdint.h>

extern "C"
{
#   include "exo_helper.h"
#   include "membuf.h"
#   include "membuf_io.h"
}

#include "WorkerThread.h"
#include "EasySplitMainFrame.h"
#include "EasySplitApp.h"


/*****************************************************************************/

WorkerThread* WorkerThread::m_pTheWorkerThread;

/*****************************************************************************/
WorkerThread::WorkerThread(
        wxEvtHandler* pEventHandler,
        const wxString& stringInputFileName,
        const wxString& stringOutputFileName, unsigned nSize1, unsigned nSizeN) :
    wxThread(wxTHREAD_JOINABLE),
    m_pEventHandler(pEventHandler),
    m_stringInputFileName(stringInputFileName),
    m_stringOutputFileName(stringOutputFileName),
    m_nSize1(nSize1),
    m_nSizeN(nSizeN)
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
    m_pEventHandler->AddPendingEvent(event);
}

/*****************************************************************************/
void* WorkerThread::Entry()
{
    struct crunch_options options = {NULL, 65535, EASY_SPLIT_MAX_EXO_OFFSET, 0};
    struct crunch_info info;
    struct membuf inbuf;
    struct membuf outbuf;

    WorkerThread_Log("Input:  %s\n", (const char*)m_stringInputFileName.mb_str());
    WorkerThread_Log("Output: %s.xx\n", (const char*)m_stringOutputFileName.mb_str());

    membuf_init(&inbuf);
    membuf_init(&outbuf);
    if (read_file(m_stringInputFileName.mb_str(), &inbuf))
        return NULL;

    crunch(&inbuf, &outbuf, &options, &info);
    WorkerThread_Log("\n");

    SaveFiles((uint8_t*) membuf_get(&outbuf), membuf_memlen(&outbuf), membuf_memlen(&inbuf));

    membuf_free(&outbuf);
    membuf_free(&inbuf);

    return NULL;
}

/*****************************************************************************/
/**
 *
 */
bool WorkerThread::SaveFiles(uint8_t* pData, size_t len, size_t nOrigLen)
{
    wxString str;
    int nRemaining;
    int nFile;
    int nSize;

    EasySplitHeader header = { { 0x65, 0x61, 0x73, 0x79, 0x73, 0x70, 0x6c, 0x74 } }; /* EASYSPLT */

    nRemaining = len + sizeof(header);
    nFile = 1;

    header.len[0] = nOrigLen % 0x100;
    header.len[1] = nOrigLen / 0x100;
    header.len[2] = nOrigLen / 0x10000;
    header.len[3] = nOrigLen / 0x1000000;

    while (nRemaining)
    {
        if (nFile == 1)
            nSize = m_nSize1;
        else
            nSize = m_nSizeN;

        if (nSize > nRemaining)
            nSize = nRemaining;

        str = m_stringOutputFileName;
        str.Append(wxString::Format(_(".%02d"), nFile));
        WorkerThread_Log("Writing %u of %u bytes to %s...\n",
                nSize, len + sizeof(header), (const char*) str.mb_str());

        wxFFile file(str, _("w"));
        if (!file.IsOpened())
        {
            WorkerThread_Log("Error: Cannot open %s for writing\n",
                    (const char*) str.mb_str());
            return false;
        }

        if (nFile == 1)
        {
            if (file.Write(&header, sizeof(header)) != sizeof(header) ||
                file.Write(pData, nSize - sizeof(header)) != nSize - sizeof(header))
            {
                WorkerThread_Log("Error: Write to %s failed\n",
                        (const char*) str.mb_str());
                return false;
            }
            pData += nSize - sizeof(header);
        }
        else
        {
            if (file.Write(pData, nSize) != nSize)
            {
                WorkerThread_Log("Error: Write to %s failed\n",
                        (const char*) str.mb_str());
                return false;
            }
            pData += nSize;
        }

        nRemaining -= nSize;
        ++nFile;
    }
    return true;
}

/*****************************************************************************/
/**
 *
 */
void WorkerThread::Log(const char* pStrFormat, va_list args)
{
    char str[200];
    vsnprintf(str, sizeof(str) - 1, pStrFormat, args);
    str[sizeof(str) - 1] = '\0';

    LogText(wxString(str, wxConvUTF8));
}


/*****************************************************************************/
/**
 *
 */
extern "C" void WorkerThread_Log(const char* pStrFormat, ...)
{
    va_list args;

    if (WorkerThread::m_pTheWorkerThread)
    {
        va_start(args, pStrFormat);
        WorkerThread::m_pTheWorkerThread->Log(pStrFormat, args);
        va_end(args);
    }
}

