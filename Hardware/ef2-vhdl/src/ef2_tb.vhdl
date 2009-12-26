
-- http://www.springer.com/cda/content/document/cda_downloaddocument/9783540736721-c1.pdf
-- 
-- 
library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use work.all;
use unisim.vcomponents.all;

entity ef2_tb is
end ef2_tb;

architecture ef2_tb_arc of ef2_tb is
    component ef2
        port (
            n_reset :   inout std_logic;
            button_a :  in std_logic;
            button_b :  in std_logic;
            button_c :  in std_logic;
            button_d :  in std_logic;
            ba :        in std_logic := '1';
            n_flash_cs : out std_logic;
            n_led :     out std_logic;
            n_irq :     out std_logic;
            n_dotclk :  in std_logic := 'X';
            n_dma :     out std_logic;
            phi2 :      in std_logic := 'X';
            n_romh :    in std_logic := 'X';
            n_roml :    in std_logic := 'X';
            n_ram_cs :  out std_logic;
            n_wr :      in std_logic := '1';
            n_nmi :     out std_logic;
            n_mem_oe :  out std_logic;
            n_io1 :     in std_logic := 'X';
            n_io2 :     in std_logic := 'X';
            n_mem_wr :  out std_logic;
            n_mem_reset: out std_logic;
            pad2 :      out std_logic;
            pad3 :      out std_logic;
            pad4 :      out std_logic;
            pad5 :      out std_logic;
            mem_data :  inout std_logic_vector(7 downto 0);
            mem_addr :  out std_logic_vector(20 downto 0);
            data :      inout std_logic_vector(7 downto 0);
            addr :      in std_logic_vector(15 downto 0)
        );
    end component;

    signal n_reset :    std_logic;
    signal button_a :   std_logic;
    signal button_b :   std_logic;
    signal button_c :   std_logic;
    signal button_d :   std_logic;
    signal ba :         std_logic;
    signal n_flash_cs : std_logic;
    signal n_led :      std_logic;
    signal n_irq :      std_logic;
    signal n_dotclk :   std_logic;
    signal n_dma :      std_logic;
    signal phi2 :       std_logic;
    signal n_romh :     std_logic;
    signal n_roml :     std_logic;
    signal n_ram_cs :   std_logic;
    signal n_wr :       std_logic;
    signal n_nmi :      std_logic;
    signal n_mem_oe :   std_logic;
    signal n_io1 :      std_logic;
    signal n_io2 :      std_logic;
    signal n_mem_wr :   std_logic;
    signal n_mem_reset: std_logic;
    signal pad2 :       std_logic;
    signal pad3 :       std_logic;
    signal pad4 :       std_logic;
    signal pad5 :       std_logic;
    signal mem_data :   std_logic_vector(7 downto 0);
    signal mem_addr :   std_logic_vector(20 downto 0);
    signal data :       std_logic_vector(7 downto 0);
    signal addr :       std_logic_vector(15 downto 0);

    -- reset at the beginning
    constant RESET_T : time := 1000 ns;

    -- cycle duration of dotclock (8 MHz assumed)
    constant DOTCLK_T : time := 125 ns;

    -- that's the time from 0 when the dotclock counter is set to 0,
    -- i.e. synchronized the first time. See process phi2_loop
    constant PHI2_SYNC_T : time := RESET_T + 2 * DOTCLK_T;

    -- cycle duration of phi2
    constant PHI2_T:  time := 8 * DOTCLK_T;

    type test_vector is record
        -- first wait for a phi2 event to this state
        phi2:           std_logic;
        -- then wait this amount of time
        wait1:          time;
        -- then set these signals
        n_reset:        std_logic;
        n_io12_romlh:   std_logic_vector(3 downto 0);
        n_wr:           std_logic;
        addr:           std_logic_vector(15 downto 0);
        data:           std_logic_vector(7 downto 0);
        -- wait again
        wait2:          time;
        -- check this
        check_mem_addr: std_logic_vector(20 downto 0);
        -- and set this
        mem_data:       std_logic_vector(7 downto 0);

    end record;

    type test_vector_array is array (natural range <>) of test_vector;

    constant test_cases: test_vector_array := (
        (phi2 => '0', wait1 => 50 ns,
         n_reset => '0', n_wr => '1', n_io12_romlh => "1111", 
         addr => x"5555", data => (others => 'Z'),
         wait2 => 50 ns,
         check_mem_addr => (others => 'U'), mem_data => (others => 'U')),

        (phi2 => '1', wait1 => 50 ns,
         n_reset => '1', n_wr => '1', n_io12_romlh => "1111",
         addr => x"5555", data => (others => 'Z'),
         wait2 => 50 ns,
         check_mem_addr => (others => 'U'), mem_data => (others => 'U')),

        (phi2 => '1', wait1 => 50 ns,
         n_reset => '1', n_wr => '1', n_io12_romlh => "0111",
         addr => x"de20", data => (others => 'Z'),
         wait2 => 150 ns,
         check_mem_addr => '0' & x"00020", mem_data => x"44"),

        (phi2 => '1', wait1 => 50 ns,
         n_reset => '1', n_wr => '0', n_io12_romlh => "0111",
         addr => x"de21", data => x"55",
         wait2 => 150 ns,
         check_mem_addr => '0' & x"00020", mem_data => x"44") --- !??
    );

begin
    uut : ef2 port map (
        n_reset => n_reset,
        button_a => button_a,
        button_b => button_b,
        button_c => button_c,
        button_d => button_d,
        ba => ba,
        n_flash_cs => n_flash_cs,
        n_led => n_led,
        n_irq => n_irq,
        n_dotclk => n_dotclk,
        n_dma => n_dma,
        phi2 => phi2,
        n_romh => n_romh,
        n_roml => n_roml,
        n_ram_cs => n_ram_cs,
        n_wr => n_wr,
        n_nmi => n_nmi,
        n_mem_oe => n_mem_oe,
        n_io1 => n_io1,
        n_io2 => n_io2,
        n_mem_wr => n_mem_wr,
        n_mem_reset => n_mem_reset,
        pad2 => pad2,
        pad3 => pad3,
        pad4 => pad4,
        pad5 => pad5,
        mem_data => mem_data,
        mem_addr => mem_addr,
        data => data,
        addr => addr
    );

    -- clock process for dotclk
    dotclk_loop : process
    begin
        n_dotclk <= '0';
        wait for DOTCLK_T / 2;
        n_dotclk <= '1';
        wait for DOTCLK_T / 2;
    end process;

    -- this process "simulates" RAM by setting data to addr
    ram_emu : process(n_ram_cs, n_mem_oe, mem_addr)
    begin
        if n_ram_cs = '0' and n_mem_oe = '0' then
            mem_data <= not mem_addr(7 downto 0);
        else
            mem_data <= (others => 'Z');
        end if;
    end process ram_emu;

    -- clock process for phi2 (with some jitter relative to dotclk)
    phi2_loop : process
    begin
        phi2 <= '1';
        wait for PHI2_SYNC_T + 10 ns;       -- phi2 low 10 ns after dotclk
        dotclk_loop : loop
            phi2 <= '0';
            wait for PHI2_T / 2 - 20 ns;    -- phi2 high 10 ns before dotclk
            phi2 <= '1';
            wait for PHI2_T / 2;            -- phi2 low 10 ns before dotclk
            phi2 <= '0';
            wait for PHI2_T / 2 + 20 ns;    -- phi2 high 10 ns after dotclk
            phi2 <= '1';
            wait for PHI2_T / 2;            -- phi2 low 10 ns after dotclk
        end loop dotclk_loop;
    end process;

    testloop: process
        variable vector: test_vector;
    begin
        for i in test_cases'range loop
            vector := test_cases(i);

            wait until phi2'event and phi2 = vector.phi2;
            wait for vector.wait1;

            -- set all inputs from test vector
            n_reset <= vector.n_reset;
            n_wr    <= vector.n_wr;
            n_io1   <= vector.n_io12_romlh(3);
            n_io2   <= vector.n_io12_romlh(2);
            n_roml  <= vector.n_io12_romlh(1);
            n_romh  <= vector.n_io12_romlh(0);
            addr    <= vector.addr;
            data    <= vector.data;

            wait for vector.wait2;

            -- check the memory address bus
            if vector.check_mem_addr(0) /= 'U' then 
                assert mem_addr = vector.check_mem_addr
                    report "Memory address bus has wrong value";
            end if;

            -- verify data bus to check response from memory
            -- wait for 20 ns;

            -- reset all control signals to their idle state
            wait until phi2'event and phi2 = not vector.phi2;
            wait for 20 ns;
            n_reset <= '1';
            n_io1   <= '1';
            n_io2   <= '1';
            n_roml  <= '1';
            n_romh  <= '1';
            n_wr    <= '1';
            data    <= (others => 'Z');

        end loop;

        wait;
    end process testloop;
    
end ef2_tb_arc;

