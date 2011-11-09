----------------------------------------------------------------------------------
--
-- (c) 2010 Thomas 'skoe' Giesel
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
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;


entity freezer is
    port (
            clk:                    in  std_logic;
            n_reset:                in  std_logic;
            phi2:                   in  std_logic;
            n_wr:                   in  std_logic;
            bus_ready:              in  std_logic;
            start_freezer:          in  std_logic;
            reset_freezer:          in  std_logic;
            freezer_irq:            out std_logic;
            freezer_ready:          out std_logic
    );
end freezer;


architecture behav of freezer is

    signal write_access_cnt:        integer range 0 to 3;
    signal freeze_pending:          std_logic;
begin

    ---------------------------------------------------------------------------
    -- When the freeze button is pressed during a bus read access we start
    -- the Freeze Pending state.
    --
    -- Currently the Freeze Pending state is only left on reset.
    ---------------------------------------------------------------------------
    freezer_start: process(clk, n_reset, reset_freezer)
    begin
        if n_reset = '0' or reset_freezer = '1' then
            freeze_pending <= '0';
        elsif rising_edge(clk) then
            if start_freezer = '1' and bus_ready = '1' and n_wr = '1' then
                freeze_pending <= '1';
            end if;
        end if;
    end process;

    freezer_irq <= freeze_pending;

    ---------------------------------------------------------------------------
    -- Count from 3 to 0 to find 3 consecutive write accesses which only
    -- happen when an IRQ or NMI is started.
    --
    ---------------------------------------------------------------------------
    freezer_count: process(clk, n_reset, reset_freezer)
    begin
        if n_reset = '0' or reset_freezer = '1' then
            write_access_cnt <= 3;
            freezer_ready <= '0';
        elsif rising_edge(clk) then
            if freeze_pending = '0' then
                write_access_cnt <= 3;
            elsif bus_ready = '1' and phi2 = '1' then
                if n_wr = '0' then
                    if write_access_cnt /= 0 then
                        write_access_cnt <= write_access_cnt - 1;
                    end if;
                    if write_access_cnt = 1 then
                        freezer_ready <= '1';
                    end if;
                else
                    write_access_cnt <= 3;
                end if;
            end if;
        end if;
    end process;

end behav;
