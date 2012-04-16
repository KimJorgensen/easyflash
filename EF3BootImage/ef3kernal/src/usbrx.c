
#include <stdint.h>
#include <string.h>

#include <ef3usb.h>

extern void usbtool_prg_load_and_run(void);

static void start_prg()
{
    usbtool_prg_load_and_run();
}


void usbrx(void)
{
    const char* p_str_cmd;

    p_str_cmd = ef3usb_check_cmd();

    if(p_str_cmd)
    {
        if (strcmp(p_str_cmd, "prg") == 0)
        {
            ef3usb_send_str("load");
            start_prg();
        }
        else
        {
            ef3usb_send_str("etyp");
        }
    }
}
