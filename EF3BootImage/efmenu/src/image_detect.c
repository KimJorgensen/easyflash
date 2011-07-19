
#include <stdint.h>
#include "efmenu.h"
#include "image_detect.h"

image_fingerprint_t kernal_signatures[] =
{
    /* offset   signature       name */
    { 0x0487,   "beast sy",     "The Beast System" },
    { 0x048d,   "exos v3 ",     "EXOS V3" },
    { 0x049b,   "dolphind",     "Dolphin DOS" }, /* 2.0, 2.1 */
};


void detect_images(efmenu_entry_t* kernal_menu)
{

}
