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


entity exp_bus_ctrl is
    port (
        clk:                in  std_logic;
        phi2:               in  std_logic;
        n_wr:               in  std_logic;

        rd:                 out std_logic;
        wr:                 out std_logic;

        -- The phase inside a Phi2 half cycle as shift register. This is used
        -- as one-hot encoded state machine to save function block inputs.
        phase_pos:          out std_logic_vector(10 downto 0);

        -- This combinatorical signal is '1' for one clk cycle
        -- after the end of each Phi2 half cycle
        cycle_start:        out std_logic;

        -- This combinatorical signal is '1' for one clk cycle at the
        -- beginning of a Phi2 cycle (when Phi2 is low)
        phi2_cycle_start:   out std_logic
    );
end exp_bus_ctrl;


architecture arc of exp_bus_ctrl is
    signal prev_phi2:       std_logic;
    signal phi2_s:          std_logic;
    signal phase_pos_i:     std_logic_vector(10 downto 0);
begin

    synchronize_stuff: process(clk)
    begin
        if rising_edge(clk) then
            prev_phi2 <= phi2_s;
            phi2_s <= phi2;
        end if;
    end process synchronize_stuff;

    ---------------------------------------------------------------------------
    -- Count cycles in both phases of phi2
    ---------------------------------------------------------------------------
    clk_phase_shift: process(clk, prev_phi2, phi2_s)
    begin
        if rising_edge(clk) then
            if prev_phi2 /= phi2_s then
                phase_pos_i <= (others => '0');
                phase_pos_i(0) <= '1';
            else
                phase_pos_i <= phase_pos_i(9 downto 0) & '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Write is only allowed at phi2 = '1', because on C128 it happens
    -- that n_wr = '0' when phi2 = '0', which is not a write access.
    ---------------------------------------------------------------------------
    check_rw: process(clk, phi2_s, n_wr)
    begin
        if rising_edge(clk) then

            if phase_pos_i(4) = '1' and (n_wr = '1' or phi2 = '0') then
                rd <= '1';
            end if;

            if phase_pos_i(6) = '1' and n_wr = '0' and phi2_s = '1' then
                wr <= '1';
                rd <= '0';
            end if;

            if phase_pos_i(7) = '1' then
                wr <= '0';
            end if;

            if prev_phi2 /= phi2_s then
                rd <= '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Create control signals depending from clk counter
    --
    -- These signals are generated combinatorically, they are to be used on the
    -- next rising edge of clk.
    --
    ---------------------------------------------------------------------------
    cycle_start <= phi2_s xor prev_phi2;
    phi2_cycle_start <= not phi2_s and phase_pos_i(0);

    phase_pos <= phase_pos_i;
end arc;
