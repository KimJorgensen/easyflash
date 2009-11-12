/*
 * EasySplit
 *
 * (c) 2003-2008 Thomas Giesel
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

#ifndef MCAPP_H
#define MCAPP_H

#include <wx/app.h>
#include <list>

#include "EasySplitMainFrame.h"

/* This must fit to the buffer size of the decruncher in EasyProg */
#define EASY_SPLIT_MAX_EXO_OFFSET (16 * 256)

class PalettePanel;
class MCChildFrame;

class EasySplitApp : public wxApp
{
public:
    EasySplitApp();
    virtual ~EasySplitApp();
    virtual bool OnInit();

    static wxImage GetImage(const wxString& dir, const wxString& name);
    static wxBitmap GetBitmap(const wxString& dir, const wxString& name);

//    MCMainFrame* GetMainFrame();
    PalettePanel* GetPalettePanel();

protected:
    EasySplitMainFrame*    m_pMainFrame;
};

DECLARE_APP(EasySplitApp)


/*****************************************************************************/
typedef struct EasySplitHeader_s
{
    char    magic[8];   /* PETSCII EASYSPLT (hex 65 61 73 79 73 70 6c 74) */
    uint8_t len[4];     /* uncompressed file size (little endian) */
    uint8_t id[2];      /* 16 bit file ID, must be constant in all parts
                         * which belong to one file. May be a random value,
                         * a checksum or whatever. */
    uint8_t nThis;      /* Number of this file (0 = 01, 1 = 02...) */
    uint8_t nFiles;     /* Total number of files */
}
EasySplitHeader;

#endif // MCAPP_H
