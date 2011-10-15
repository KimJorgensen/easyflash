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
use work.cartridge_modes.all;


entity exp_bus_ctrl is
    port (
        clk:        in  std_logic;
        phi2:       in  std_logic;

        -- This combinatorical signal is '1' for one clk cycle at the
        -- beginning of a Phi2 cycle (when Phi2 is low)
        phi2_cycle_start: out std_logic;

        addr_ready: out std_logic;

        -- This combinatorical signal is '1' for one clk cycle
        -- when the PLA result for the current address is stable, this is the
        -- case between 200 ns to 240 ns after Phi2 edges.
        bus_ready:  out std_logic;

        -- After the KERNAL implementation changed the address bus, ROMH has to be
        -- examined. This combinatorical signal is '1' for one clock cycle when ROMH
        -- is ready. That's 280 ns to 320 ns after Phi2 edges.
        hiram_detect_ready:  out std_logic;

        -- This combinatorical signal is '1' for one clk cycle
        -- after the end of each Phi2 half cycle
        cycle_end:  out std_logic
    );
end exp_bus_ctrl;


architecture arc of exp_bus_ctrl is
    signal prev_phi2:   std_logic;
    signal phi2_s:      std_logic;
    signal cycle_end_i: std_logic;
    signal clk_cnt:     integer range 0 to 13; -- 25 MHz ~ 0.5 us
begin

    synchronize_stuff: process(clk)
    begin
        if rising_edge(clk) then
            prev_phi2 <= phi2_s;
            phi2_s <= phi2;
        end if;
    end process synchronize_stuff;

    ---------------------------------------------------------------------------
    -- Count cycles of clk
    ---------------------------------------------------------------------------
    clk_counter: process(clk)
    begin
        if rising_edge(clk) then
            if prev_phi2 /= phi2_s then
                clk_cnt <= 0;
            else
                clk_cnt <= clk_cnt + 1;
            end if;
        end if;
    end process clk_counter;

    ---------------------------------------------------------------------------
    -- Create control signals depending from clk counter
    --
    -- This signals are generated combinatorically, they are to be used on the
    -- next rising edge of clk.
    ---------------------------------------------------------------------------
    bus_states: process(clk_cnt, prev_phi2, phi2_s, phi2)
    begin
        addr_ready  <= '0';
        bus_ready   <= '0';
        hiram_detect_ready <= '0';

        if prev_phi2 /= phi2_s then
            cycle_end_i <= '1';
        else
            cycle_end_i <= '0';
        end if;

        if clk_cnt = 3 then
            addr_ready <= '1';
        end if;
        if clk_cnt = 5 then
            bus_ready <= '1';
        end if;
        if clk_cnt = 7 then
            hiram_detect_ready <= '1';
        end if;

    end process bus_states;

    cycle_end <= cycle_end_i;
    phi2_cycle_start <= not phi2_s and cycle_end_i;
end arc;
