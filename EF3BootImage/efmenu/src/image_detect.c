
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "efmenu.h"
#include "image_detect.h"

#define ROML ((uint8_t*) 0x8000)

image_fingerprint_t kernal_signatures[] =
{
    /* offset   signature       name */
    { 0x049b,   { 0x44, 0x4f, 0x4c, 0x50, 0x48, 0x49, 0x4e, 0x44 }, "Dolphin DOS" }, /* 2.0, 2.1 */
    { 0x048d,   { 0x45, 0x58, 0x4F, 0x53, 0x20, 0x56, 0x33, 0x20 }, "EXOS V3" },
    { 0x047c,   { 0x4a, 0x49, 0x46, 0x46, 0x59, 0x44, 0x4f, 0x53 }, "Jiffy DOS" },
    { 0x0487,   { 0x42, 0x45, 0x41, 0x53, 0x54, 0x20, 0x53, 0x59 }, "The Beast System" },
    { 0x047e,   { 0x54, 0x54, 0x2d, 0x52, 0x4f, 0x4d, 0x20, 0x2f }, "Turbo Tape" },

    { 0xffff, {0, 0, 0, 0, 0, 0, 0, 0}, NULL } /* end mark */
};


void detect_images(efmenu_entry_t* kernal_menu)
{
    char found;
    efmenu_entry_t* entry;
    image_fingerprint_t* fp;

    entry = kernal_menu;
    while (entry->key)
    {
        set_bank(entry->bank);
        fp = kernal_signatures;
        found = 0;
        while (fp->offset != 0xffff)
        {
            if (memcmp(ROML + fp->offset, fp->signature,
                       IMAGE_SIGNATURE_LEN) == 0)
            {
                entry->name = fp->name;
                found = 1;
                break;
            }
            ++fp;
        }
        if (!found && ((ROML[0x1ffc] != 0xff) || (ROML[0x1ffd] != 0xff)))
        {
            entry->name = "Unknown KERNAL";
        }
        ++entry;
    }
}
