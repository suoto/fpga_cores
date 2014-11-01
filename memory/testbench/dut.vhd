--------------------------------------------------------
-- Simple Microprocessor Design
--
-- Microprocessor composed of
-- Ctrl_Unit, Data_Path and Memory
-- structural modeling
-- microprocessor.vhd
--------------------------------------------------------

library	ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;
    use ieee.std_logic_unsigned.all;

library work;
    use work.ram_model_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

library common_lib;
    use common_lib.common_pkg.all;

library memory;

entity dut is
end dut;

architecture dut of dut is

    constant WR_CLK_PERIOD : time := 4 ns;
    constant RD_CLK_PERIOD : time := 9 ns;

    constant ADDR_WIDTH         : positive := 16;
    constant DATA_WIDTH         : positive := 16;
    constant EXTRA_OUTPUT_DELAY : natural  := 0;

    signal wr_clk    : std_logic := '0';
    signal wr_clken  : std_logic;
    signal wr_rst    : std_logic;
    signal wr_en     : std_logic;
    signal wr_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);


    signal rd_clk    : std_logic := '0';
    signal rd_rst    : std_logic;
    signal rd_clken  : std_logic;
    signal rd_en     : std_logic;
    signal rd_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);


    begin

        wr_clk <= not wr_clk after WR_CLK_PERIOD/2;
        rd_clk <= not rd_clk after RD_CLK_PERIOD/2;

        wr_clken <= '1';
        rd_clken <= '1';

        wr_rst <= '1', '0' after 16*WR_CLK_PERIOD;
        rd_rst <= '1', '0' after 16*RD_CLK_PERIOD;
    
        dut : entity memory.async_fifo
            generic map (
                FIFO_LEN   => 512,
                DATA_WIDTH => DATA_WIDTH
            )
            port map (
                -- Write port
                wr_clk      => wr_clk, 
                wr_clken    => wr_clken, 
                wr_rst      => wr_rst,
                wr_data     => wr_data, 
                wr_en       => wr_en, 
                wr_full     => open, 
        
                rd_clk      => rd_clk, 
                rd_clken    => rd_clken, 
                rd_rst      => rd_rst,
                rd_data     => rd_data, 
                rd_en       => rd_en, 
                rd_dv       => open, 
                rd_empty    => open
            );

    process
    begin
        wr_en <= '0';    
        wait until wr_rst = '0';
        for i in 0 to 20 loop
            wait until wr_clk = '1';
        end loop;
        for i in 0 to 511 loop
            wr_en <= '1';    
            wait until wr_clk = '1';
            wr_en <= '0';    
            wait until wr_clk = '1';
        end loop;
        wait;
    end process;
end dut;

