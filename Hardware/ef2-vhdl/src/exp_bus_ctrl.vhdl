----------------------------------------------------------------------------------
-- Expansion Port Bus Control
----------------------------------------------------------------------------------
-- 
-- dotclk: T ~ 125 ns (note: actually n_dotclk is negated)
--       ---     ---     ---     ---     ---     ---     ---     ---     ---
--  \ 0 /   \ 1 /   \ 2 /   \ 3 /   \ 4 /   \ 5 /   \ 6 /   \ 7 /   \ 0 /   \
--   ---     ---     ---     ---     ---     ---     ---     ---     ---     -
--  .       .       .       .       .       .       .       .
-- phi2:    .       .       .       .       .       .       .
--  +?ns    .       .       .       +?ns    .       .       .
--  |=>|    .       .       .       |=>|    .       .       .
--      -------------------------------                                 --
--     /                               \                               /
--  ---                                 -------------------------------
--          .       .       .       .  .    .       .       .          .
-- bus states:      .       .       .  .    .       .       .          .
--          .       .       .       .  .    .       .       .          .
--      if RW is 0: X ====> X ====> X  .    .       .       .          .
--          .     Write   Write   Idle .    .       .       .          .
--          .     valid   enable    .  .    .       .       .          .
--          .      (1)     (2)      .  .    .       .       .          .
--          .               .       .  .    .       .       .          .
--      if RW is 1: X ====================> X       .       .          .
--          .     Read      .       .  .  Idle      .       .          .
--          .     valid     .       .  .   (4)      .       .          .
--          .      (3)      .       .  .            .       .          .
--          .               >-Out-ena---< (5)        .       .          .
--          .                                               .          .
--          .          if LOROM is 0 or HIROM is 0 (read from VIC):    .
-- ...====> X                                         X ===================...
--        Idle                                   Read       .          .
--         (4)                                    valid     .          .
--                                                 (3)      .          .
--                                                          >-Out-ena---< (5)
-- 
-- Note (1): Due to AEC from VIC-II, addresses and data are not stable 
-- immediately after the phi2 edge. We generate a safe timing using (n_)dotclk.
-- At the beginning of dotclk cycle 2 the address and data for a write access 
-- can be clocked from the c64 bus to our memory bus.
-- 
-- Note (2): One dotclock cycle after applying address and data to our memory
-- bus, we can activate /CE and /WE to the memory chip.
-- 
-- Note (3): Same as (1), but for read access. The signals /CS and /OE of the
-- addressed memory chip are activated in this step.
-- 
-- Note (4): We leave the memory chip enabled for a while. It is deactivated
-- after output is disabled.
--
-- Note (5): Output enable for expansion port data bus. This may become active
-- as soon as port_read_complete is active. It is reset asynchronously when
-- phi2 changes its state.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.ef2_types.all;

entity exp_bus_ctrl is
    port ( 
            n_roml:     in std_logic;
            n_romh:     in std_logic;
            n_io1:      in std_logic;
            n_io2:      in std_logic;
            n_wr:       in std_logic;
            n_reset:    inout std_logic;
            n_dotclk:   in std_logic;
            phi2:       in std_logic;
            bus_next_state:     out bus_state_type;
            bus_current_state:  out bus_state_type;
            bus_out_enable:     out std_logic
    );
end exp_bus_ctrl;


architecture exp_bus_ctrl_arc of exp_bus_ctrl is

    -- next state of the bus, detected combinatorically
    signal bus_next_state_i:  bus_state_type;

    -- current state of the bus
    signal bus_current_state_i: bus_state_type;

    -- count dotclk cycles in a phi2 cycle, 0 when rising edge of phi2 happens
    signal dotclk_cnt:      std_logic_vector(2 downto 0);

    -- Remember the state of phi2 on previous dotclk edge
    signal prev_phi2:       std_logic;

begin

    ---------------------------------------------------------------------------
    -- Count cycles of dotclock 0..7
    --
    -- Our CPLD has async CLRs and we know that phi2 changes somewhere in the 
    -- middle between two rising edges of our n_dotclk. Therefore we reset the
    -- counter asynchronously when phi2 changes from 0 to 1.
    ---------------------------------------------------------------------------
    dotclk_counter: process(n_dotclk, phi2, dotclk_cnt)
    begin
        if prev_phi2 = '0' and phi2 = '1' and dotclk_cnt /= "000" then
            dotclk_cnt <= (others => '0');
        elsif rising_edge(n_dotclk) then
            dotclk_cnt <= dotclk_cnt + 1;
        end if;
    end process dotclk_counter;

    ---------------------------------------------------------------------------
    -- Remember the phi2 state on each dotclk edge, used to synchronize
    -- dotclk_cnt to phi2, see process dotclk_counter
    ---------------------------------------------------------------------------
    save_prev_phi2: process(n_dotclk)
    begin
        if rising_edge(n_dotclk) then
            prev_phi2 <= phi2;
        end if;
    end process save_prev_phi2;

    ---------------------------------------------------------------------------
    -- Find out which state the expansion port bus will have on the *next*
    -- dotclk edge. This is combinatoric logic.
    ---------------------------------------------------------------------------
    check_next_state : process(dotclk_cnt, n_wr,
                               n_io1, n_io2, n_roml, n_romh)
    begin

        case bus_current_state_i is

            when BUS_IDLE =>
                if dotclk_cnt = x"1" then
                    if n_wr = '0' then
                        bus_next_state_i <= BUS_WRITE_VALID;
                    else
                        bus_next_state_i <= BUS_READ_VALID;
                    end if;
                elsif dotclk_cnt = x"5" and (n_roml = '0' or n_romh = '0') then
                    -- On C128 in Ultimax mode n_wr is don't care
                    -- when VIC-II reads from Cartridge ROM
                    bus_next_state_i <= BUS_READ_VALID;
                else
                    bus_next_state_i <= BUS_IDLE;
                end if;

            when BUS_WRITE_VALID =>
                    bus_next_state_i <= BUS_WRITE_ENABLE;

            when BUS_WRITE_ENABLE =>
                    bus_next_state_i <= BUS_IDLE;

            when BUS_READ_VALID =>
                if dotclk_cnt = x"0" or dotclk_cnt = x"4" then
                    bus_next_state_i <= BUS_IDLE;
                else
                    bus_next_state_i <= BUS_READ_VALID;
                end if;
        end case;
        
    end process check_next_state;

    bus_next_state <= bus_next_state_i;

    ---------------------------------------------------------------------------
    -- Make the next state of the expansion port bus to the current state
    ---------------------------------------------------------------------------
    enter_next_state: process(n_dotclk, n_reset)
    begin
        if n_reset = '0' then
                bus_current_state_i <= BUS_IDLE;
        elsif rising_edge(n_dotclk) then
            bus_current_state_i <= bus_next_state_i;
        end if;
        
    end process enter_next_state;

    bus_current_state <= bus_current_state_i;

    ---------------------------------------------------------------------------
    -- Create the output enable signal for the expansion port data bus.
    -- It is activated in cylce 2 or 6 of dotclock when there's a read access
    -- to our address space.
    -- I is deactivated asynchronously when n_io1, n_io2, n_roml and n_romh
    -- get inactive.
    --
    -- Remember that VIC-II can read data from cartridge ROM e.g. in Ultimax
    -- mode when phi2 is low. In this case n_wr is don't care because it has
    -- a wrong state on C128.
    ---------------------------------------------------------------------------
    check_port_out_enable: process(phi2, n_dotclk, 
                                   n_io1, n_io2, n_roml, n_romh)
        variable cart_addressed: boolean;
    begin
        if n_io1 = '0' or n_io2 = '0' or n_roml = '0' or n_romh = '0' then
            cart_addressed := true;
        else
            cart_addressed := false;
        end if;

        if not cart_addressed then
            bus_out_enable <= '0';
        elsif rising_edge(n_dotclk) then
            -- CPU read or VIC-II read
            if (dotclk_cnt = x"1" and n_wr = '1' and cart_addressed) or
               (dotclk_cnt = x"5" and cart_addressed)
            then
                bus_out_enable <= '1';
            end if;
        end if;
    end process check_port_out_enable;

end exp_bus_ctrl_arc;
    