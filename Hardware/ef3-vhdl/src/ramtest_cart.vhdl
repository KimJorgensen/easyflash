----------------------------------------------------------------------------------
--
-- (c) 2011 Thomas 'skoe' Giesel
--
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
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ramtest_cart is
    port (
        n_io1:      in  std_logic;
        n_wr:       in  std_logic;
        addr_ready: in  std_logic;
        data_ready: in  std_logic;
        addr:       in  std_logic_vector(7 downto 0);
        addr_out:   out std_logic_vector(7 downto 0);
        ramtest_ram_read:  out std_logic;
        ramtest_ram_write: out std_logic
    );
end ramtest_cart;

architecture ramtest_cart_arc of ramtest_cart is 
begin
    addr_out <= addr;

    read_ram: process(n_io1, n_wr, addr_ready, data_ready)
    begin
        ramtest_ram_write <= '0';
        ramtest_ram_read <= '0';
        if n_io1 = '0' then
            if n_wr = '1' and addr_ready = '1' then
                ramtest_ram_read <= '1';
            elsif n_wr = '0' and data_ready = '1' then
                ramtest_ram_write <= '1';
            end if;
        end if;
    end process;
    
end architecture ramtest_cart_arc;
