/*
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

#ifdef __WXMAC__
#include <ApplicationServices/ApplicationServices.h>
#endif // __WXMAC__

#include <wx/menu.h>
#include <wx/image.h>
#include <wx/stdpaths.h>
#include <wx/filename.h>
#include <wx/msgdlg.h>
#include <wx/cmdline.h>

#include "EasySplitApp.h"

static const wxCmdLineEntryDesc cmdLineDesc[] =
{
    {
        wxCMD_LINE_PARAM,  NULL, NULL, wxT("image file"),
        wxCMD_LINE_VAL_STRING,
        wxCMD_LINE_PARAM_MULTIPLE | wxCMD_LINE_PARAM_OPTIONAL
    },
    { wxCMD_LINE_NONE }
};

IMPLEMENT_APP(EasySplitApp);

/*****************************************************************************/
EasySplitApp::EasySplitApp()
{
#ifdef __WXMAC__
    ProcessSerialNumber psn;
    GetCurrentProcess(&psn);
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
#endif // __WXMAC__
}

/*****************************************************************************/
EasySplitApp::~EasySplitApp()
{
}

/*****************************************************************************/
bool EasySplitApp::OnInit()
{
    size_t i;
#if 0
    wxCmdLineParser cmdLineParser(cmdLineDesc, argc, argv);

    if (cmdLineParser.Parse() != 0)
        return false;

    wxInitAllImageHandlers();
#endif
    m_pMainFrame = new EasySplitMainFrame(NULL, _("EasySplit 0.1.0"));
    m_pMainFrame->Show();
    SetTopWindow(m_pMainFrame);
#if 0
    // open all files given on the command line
    for (i = 0; i < cmdLineParser.GetParamCount(); ++i)
    {
//        m_pMainFrame->LoadDoc(cmdLineParser.GetParam(i));
    }
#endif
    return true;
}

/*****************************************************************************/
/*
 * Load an image from our ressources. If our executable is located in $(X),
 * search in $(X)/res first and then in $(X)/../share/multicolor.
 */
wxImage EasySplitApp::GetImage(const wxString& dir, const wxString& name)
{
    wxStandardPaths paths;

    // Find out the path of our images
    wxFileName fileName(paths.GetExecutablePath());

    fileName.AppendDir(wxT("res"));
    fileName.AppendDir(dir);
    fileName.SetFullName(name);

    if (!fileName.IsFileReadable())
    {
        fileName.Assign(paths.GetExecutablePath());
        fileName.RemoveLastDir();
        fileName.AppendDir(wxT("share"));
        fileName.AppendDir(wxT("multicolor"));
        fileName.AppendDir(wxT("res"));
        fileName.AppendDir(dir);
        fileName.SetFullName(name);
    }

    return wxImage(fileName.GetFullPath(), wxBITMAP_TYPE_PNG);
}


/*****************************************************************************/
/*
 * Load a bitmap from our ressources. If our executable is located in $(X),
 * search in $(X)/res first and then in $(X)/../share/multicolor.
 */
wxBitmap EasySplitApp::GetBitmap(const wxString& dir, const wxString& name)
{
    return wxBitmap(GetImage(dir, name));
}
