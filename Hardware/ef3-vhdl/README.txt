
EasyFlash 3 CPLD Firmware version 1.2.0, April 2018, are
Copyright (c) 2018 Kim Jorgensen, are derived from EasyFlash 3 CPLD Firmware 1.1.1,
and are distributed according to the same disclaimer and license as
EasyFlash 3 CPLD Firmware 1.1.1

EasyFlash 3 CPLD Firmware versions 0.9.0, December 2011, through 1.1.1, August 2012, are
Copyright (c) 2011-2012 Thomas 'skoe' Giesel

License
=======

-- This software is provided 'as-is', without any express or implied
-- warranty.  In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.


Changes
=======

Version 1.2.0 - 19.04.2018

- Release from https://github.com/KimJorgensen/easyflash
- Final Cartridge III support

Version 1.1.1 - 18.08.2012

- Re-enabled AR/RR-mode, which I forgot in 1.0.0 *fp*

Version 1.1.0 - 17.08.2012

- Improved compatibility of KERNAL implementation

Version 1.0.0 - 06.06.2012

- USB and I/O2 RAM are also active in KERNAL mode
  - Allows USB-related features in a special KERNAL currently being
    developed
- KERNAL implementation uses a cleaner timing now
- CPLD Version register added ($de08)
  - Will be displayed in the next menu version, not release yet
- Improved C128 support
  - 2 MHz mode works in EasyFlash mode (needed for PoP)
  - Added a way to leave to C64 mode or to C128 mode
    - Will need a menu update, not release yet
  - Still NO external KERNAL on C128!
- Many optimizations to get all this crap into the CPLD

Some of the features will need a software update which is not release yet.
Do not try to start an external KERNAL on the C128, it will crash.

Version 0.9.2 - 09.01.2012

- LED implemented
  - In EasyFlash mode: LED controlled by software
  - In AR/RR/NP/SS5 mode: On when cartridge is active, off when it is inactive

Version 0.9.1 - 19.12.2011

- Weird glitch in A14 fixed

Version 0.9.0 - 18.12.2011

- First pre-release
- Known limitation: No or only very limited support for C128
- USB not tested
