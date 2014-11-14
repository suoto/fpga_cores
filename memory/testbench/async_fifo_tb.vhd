
library	ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;
    use ieee.std_logic_unsigned.all;

library work;
--    use work.ram_model_pkg.all;
    use work.fifo_bfm_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

library common_lib;
    use common_lib.common_pkg.all;

library memory;

--library std;
--    use std.env.all;


entity async_fifo_tb is
end async_fifo_tb;

architecture async_fifo_tb of async_fifo_tb is


    constant ADDR_WIDTH         : positive := 16;
    constant DATA_WIDTH         : positive := 16;
    
    signal WR_CLK_PERIOD : time := 4 ns;
    signal RD_CLK_PERIOD : time := 16 ns;

    signal wr_clk    : std_logic := '0';
    signal wr_clken  : std_logic;
    signal wr_rst    : std_logic;
    signal wr_en     : std_logic;
    signal wr_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);


    signal rd_clk    : std_logic := '0';
    signal rd_rst    : std_logic;
    signal rd_clken  : std_logic;
    signal rd_en     : std_logic;
    signal rd_dv     : std_logic;
    signal rd_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);

    shared variable fifo : fifo_bfm_type;

begin

        wr_clk <= not wr_clk after WR_CLK_PERIOD/2;
        rd_clk <= not rd_clk after RD_CLK_PERIOD/2;

        wr_clken <= '1';
        rd_clken <= '1';

        wr_rst <= '1', '0' after 16*WR_CLK_PERIOD;
        rd_rst <= '1', '0' after 16*RD_CLK_PERIOD;
    
        dut : entity memory.async_fifo
            generic map (
                FIFO_LEN        => 512,
                DATA_WIDTH      => DATA_WIDTH,
                UPPER_TRESHOLD  => 500,
                LOWER_TRESHOLD  => 10,
                OVERFLOW_ACTION => "SATURATE",
                UNDERFLOW_ACTION=> "SATURATE"
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
                rd_dv       => rd_dv, 
                rd_empty    => open
            );

    rd_en <= '1';

    process
        variable wr_data_v : std_logic_vector(DATA_WIDTH - 1 downto 0);
        variable rd_data : std_logic_vector(15 downto 0);
    begin
--        wr_en     <= '0';    
--        wr_data_v := (others => '0');
--        wait until wr_rst = '0';
--        for i in 0 to 20 loop
--            wait until wr_clk = '1';
--        end loop;
--        for i in 0 to 511 loop
--            wr_data_v := wr_data_v + 1;
--            wr_en     <= '1';    
--            wr_data   <= wr_data_v;
--            wait until wr_clk = '1';
----            wr_en <= '0';    
----            wait until wr_clk = '1';
--        end loop;
--        wr_en     <= '0';   

        fprint("Writing data\n");
        fifo.write(1);
        for i in 0 to integer(2**10) loop
            fifo.write(i);
            wait for 1 us;
        end loop;
--        for i in 0 to 2**10 loop
--            fifo.write(i);
--        end loop;
        fprint("Reading data\n");
        while not fifo.is_empty loop
            rd_data := fifo.read;
        end loop;

        fifo.free;
        
--        finish(2);

        wait;
    end process;
end async_fifo_tb;

