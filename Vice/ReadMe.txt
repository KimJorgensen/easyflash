Welcome to the EasyFlash patch for vice.

only read only access is emulated.

in src/c64/cart/easyflash.c you can change some settings:
EASYFLASH_DEBUG: (default on)
  print a debug line when something is written to register 1
  or when the contents of register 2 (ignoring led state) changes.

EASYFLASH_RAM: (default off)
  emulates 256 byte ram at $df00-$dfff

EASYFLASH_LED_USE: (default off)
  emulate the led by changing one byte of colorram
  each time something is written to register 2.
  EASYFLASH_LED_POSITION:
    on which position of the screen the color
    should be changed (0-1000 / $000-$3e7)
  EASYFLASH_LED_OFF_COLOR:
    which color should be shown when the les id off
  EASYFLASH_LED_ON_COLOR:
    which color should be shown when the les id on

EASYFLASH_EXTENDED_DEBUG: (default off)
    the extended debug activates four magic bytes at $defc-$deff.
    it allows also to dis-/enable debugging, but forced debugging and the
    reset information line is always shown. during the reset the buffer is
    cleared and the mark is set to 0.
  read $defc = always value $45 (ASCII 'E')
  write $defc = enables debugging (any value)
  read $defd = always value $46 (ASCII 'F')
  write $defc = disables debugging (any value)
  read $defe = always value $64 (ASCII 'd')
  write $defe = store the written value into a buffer
  read $deff = number of the current mark (will be $00-$7f)
  write $deff
    $00-$7f = set mark X: store the mark and print a debug line
              with the mark (if mark is $20-$7e the corresponding
              ASCII char is printed)
    $80 = clear buffer
    $81 = print the buffer in hex, LSBF, and a decimal representation
    $82 = print the buffer as ASCII (non printable chars will be converted
          to "[$xx]")
    $c1 = like $81 but ignore the disable debugging flag
    $c2 = like $82 but ignore the disable debugging flag
    all other values are reserved for future use.
    
    EASYFLASH_PRINTER_LEN:
      how many bytes the input buffer (see write $defe) has
