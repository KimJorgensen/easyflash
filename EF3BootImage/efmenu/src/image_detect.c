
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "efmenu.h"
#include "image_detect.h"

image_fingerprint_t kernal_signatures[] =
{
    /* offset   signature       name */
    { 0x0487,   "beast sy",     "The Beast System" },
    { 0x048d,   {0x45, 0x58, 0x4F, 0x53, 0x20, 0x56, 0x33, 0x20}, "EXOS V3" },
    { 0x049b,   "dolphind",     "Dolphin DOS" }, /* 2.0, 2.1 */

    { 0xffff, {0, 0, 0, 0, 0, 0, 0, 0}, NULL } /* end mark */
};


void detect_images(efmenu_entry_t* kernal_menu)
{
    efmenu_entry_t* entry;
    image_fingerprint_t* fp;

    entry = kernal_menu;
    while (entry->key)
    {
        set_bank(entry->bank);
        fp = kernal_signatures;
        while (fp->offset != 0xffff)
        {
            if (memcmp((uint8_t*) 0x8000 + fp->offset,
                       fp->signature,
                       IMAGE_SIGNATURE_LEN) == 0)
            {
                entry->name = fp->name;
                break;
            }
            ++fp;
        }
        ++entry;
    }
}
