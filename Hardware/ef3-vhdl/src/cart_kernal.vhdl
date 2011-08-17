
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cart_kernal is
    port (
        clk:        in  std_logic;
        n_reset:    in  std_logic;
        enable:     in  std_logic;
        phi2:       in  std_logic;
        ba:         in  std_logic;
        n_romh:     in  std_logic;
        n_wr:       in  std_logic;
        addr_ready: in  std_logic;
        dma_ready:  in  std_logic;
        hiram_detect_ready: in std_logic;
        cycle_end:  in  std_logic;
        addr:       in  std_logic_vector(15 downto 0);
        mem_addr:   out std_logic_vector(12 downto 0);
        latch_mem_addr: out std_logic;
        ma19:       out std_logic;
        latch_ma19: out std_logic;
        n_dma:      out std_logic;
        a14:        out std_logic;
        n_game:     out std_logic;
        n_exrom:    out std_logic;
        flash_read: out std_logic;
        hiram:      out std_logic
    );
end cart_kernal;

architecture behav of cart_kernal is
    signal kernal_space_addressed:  boolean;
    signal kernal_space_cpu_read:   boolean;
    signal kernal_read_active:      boolean;
begin

    kernal_space_addressed <= true when addr(15 downto 13) = "111" else false;

    kernal_space_cpu_read <= true when kernal_space_addressed and
        phi2 = '1' and ba = '1' and n_wr = '1'
        else false;

    detect_hiram: process(enable, clk)
    begin
        if rising_edge(clk) then
            if enable = '1' then
                if dma_ready = '1' and kernal_space_cpu_read then
                    -- Address lines are tristated/pulled up now
                    n_game  <= '0';
                    n_exrom <= '0';
                    a14 <= '0';
                    kernal_read_active <= true;
                end if;
                if kernal_read_active and hiram_detect_ready = '1' then
                    -- ROMH reflects HIRAM now
                    a14 <= 'Z';
                    if n_romh = '1' then
                        -- ram
                        n_game  <= '1';
                        n_exrom <= '1';
                    else
                        -- rom
                        n_exrom <= '1'; -- Ultimax mode
                    end if;
                end if;
                if cycle_end = '1' then
                    -- KERNAL read complete
                    n_dma <= '1';
                    n_game  <= '1';
                    n_exrom <= '1';
                    a14 <= 'Z';
                    kernal_read_active <= false;
                end if;
            else
                n_dma <= '1';
                n_game  <= '1';
                n_exrom <= '1';
                a14 <= 'Z';
                hiram <= '0';
            end if; -- enable
        end if; -- clk
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorical logic to prepare the address to be latched to the
    -- internal address bus. Additionally the signal which enables
    -- the latches at the next CLK cycle is prepared here.
    ---------------------------------------------------------------------------
    create_mem_addr: process(enable, addr, addr_ready,
                             kernal_space_cpu_read)
    begin
        flash_read <= '0';
        mem_addr <= (others => '0');
        latch_mem_addr <= '0';
        latch_ma19 <= '0';

        if enable = '1' then
            if addr_ready = '1' and kernal_space_cpu_read then
                    -- start speculative flash read to hide its latency
                    mem_addr <= addr(12 downto 0);
                    latch_mem_addr <= '1';
                    latch_ma19 <= '1';
                    flash_read <= '1';
            end if;
        end if;
    end process;

    -- always read from part usually used for ROML, because there we have
    -- the boot sectors which contain the KERNAL images
    ma19 <= '0';

end architecture behav;
