This directory contans patches for either
old vice releases or old easyflash hardware
versions.

everytime the easyflash hardware changes the cartridge id is
bumped by one. this behavior will stop when we have a "assigned"
cartridge id.

currently here:
- vice-2.1-patch-ef40.patch (hw1)
  first hardware version: one 8bit register
- vice-2.1-patch-ef41.patch (hw2)
  second hardware version: 6bit banking register, 2bit mode register (old style)
- vice-2.1-patch-er42.patch (hw3)
  third hardware version: 6bit banking register, one free register, 4 bit mode register (new style)

from now on we have a assigend cartridge id "32".
