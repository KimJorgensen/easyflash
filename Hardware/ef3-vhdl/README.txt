
EasyFlash 3 CPLD Firmware

(C) Thomas 'skoe' Giesel

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

Version 1.0.0 - xx.xx.xxxx

- USB and I/O2 RAM are also active in KERNAL mode
- CPLD Version register added ($de08)

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
