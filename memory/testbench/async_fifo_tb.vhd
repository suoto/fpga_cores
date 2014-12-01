
library	ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;
    use ieee.std_logic_unsigned.all;

library work;
    use work.ram_model_pkg.all;
    use work.fifo_bfm_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;
library common_lib;
    use common_lib.common_pkg.all;
library osvvm_lib;
    use osvvm_lib.RandomPkg.all;

library memory;

library std;
    use std.env.all;


entity async_fifo_tb is
end async_fifo_tb;

architecture async_fifo_tb of async_fifo_tb is

    constant ADDR_WIDTH         : integer := 16;
    constant DATA_WIDTH         : integer := 16;
    constant UPPER_TRESHOLD     : integer := 500;
    constant LOWER_TRESHOLD     : integer := 10;

    signal WR_CLK_PERIOD : time := 4 ns;
    signal RD_CLK_PERIOD : time := 16 ns;

    signal wr_clk    : std_logic := '0';
    signal wr_clken  : std_logic;
    signal wr_rst    : std_logic;
    signal wr_en     : std_logic;
    signal wr_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal wr_upper  : std_logic;
    signal wr_full   : std_logic;

    signal rd_clk    : std_logic := '0';
    signal rd_rst    : std_logic;
    signal rd_clken  : std_logic;
    signal rd_en     : std_logic;
    signal rd_dv     : std_logic;
    signal rd_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rd_empty  : std_logic;

    shared variable fifo     : fifo_bfm_type;
    shared variable rand_gen : RandomPType;

    type test_state_t is (upper_test_write, upper_test_read);
    signal test_state : test_state_t := upper_test_write;

begin

    wr_clk <= not wr_clk after WR_CLK_PERIOD/2;
    rd_clk <= not rd_clk after RD_CLK_PERIOD/2;

    wr_clken <= '1';
    rd_clken <= '1';

    wr_rst <= '1', '0' after 16*RD_CLK_PERIOD;
    rd_rst <= '1', '0' after 16*RD_CLK_PERIOD;

    dut : entity memory.async_fifo
        generic map (
            FIFO_LEN        => 512,
            DATA_WIDTH      => DATA_WIDTH,
            UPPER_TRESHOLD  => UPPER_TRESHOLD,
            LOWER_TRESHOLD  => LOWER_TRESHOLD,
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
            wr_full     => wr_full,
            wr_upper    => wr_upper,

            -- Read port
            rd_clk      => rd_clk, 
            rd_clken    => rd_clken, 
            rd_rst      => rd_rst,
            rd_data     => rd_data, 
            rd_en       => rd_en, 
            rd_dv       => rd_dv, 
            rd_empty    => rd_empty
        );

    process
        procedure wait_clock (c : integer) is
            begin
                for i in 1 to c loop
                    wait until wr_clk = '1';
                end loop;
            end procedure wait_clock;

        procedure write_data (d : std_logic_vector) is
            begin
                wr_en <= '1';
                wr_data <= d;
                wait until wr_clk = '1';
                wr_en <= '0';
            end procedure write_data;

        procedure write_data (d : integer) is
            begin
                write_data(conv_std_logic_vector(d, DATA_WIDTH));
            end procedure write_data;

        variable wr_data_v : std_logic_vector(DATA_WIDTH - 1 downto 0);

    begin
        test_state <= upper_test_write;
        wr_en <= '0';
        wait until wr_rst = '0';
        wait_clock(4);
        for i in 0 to UPPER_TRESHOLD loop
            assert wr_full /= '1'
                report "Error: wr_full = " & std_logic'image(wr_full) & ", it should be '0'"
                severity error;
            assert wr_upper /= '1'
                report "Error: wr_upper = " & std_logic'image(wr_full) & ", it should be '0'"
                severity error;
            wr_data_v := rand_gen.RandSlv(DATA_WIDTH);
            write_data(wr_data_v);
            fifo.write(wr_data_v);
        end loop;
        wait_clock(1);
        assert wr_full /= '1'
            report "Error: wr_full = " & std_logic'image(wr_full)
            severity error;

        assert wr_upper = '1'
            report "Error: wr_upper = " & std_logic'image(wr_full) & ", it should be '1'"
            severity error;

        test_state <= upper_test_read;
        wait;

        for i in 1 to 15 loop --2**16 loop
            fifo.write(i);
            write_data(i);
        end loop;

        wait for 10 us;
        finish(2);

        wait;
    end process; 

    process
        procedure wait_clock ( c : integer) is
            begin
                for i in 1 to c loop
                    wait until rd_clk = '1';
                end loop;
            end procedure wait_clock;

        procedure read_data (d : out std_logic_vector) is
            begin
                rd_en <= '1';
                wait until rd_clk = '1';
                rd_en <= '0';
                wait until rd_clk = '1';
                d     := rd_data;
            end procedure read_data;

        variable rd_data      : std_logic_vector(DATA_WIDTH - 1 downto 0);
        variable fifo_rd_data : std_logic_vector(DATA_WIDTH - 1 downto 0);

    begin
        rd_en <= '0';
        wait until rd_rst = '0';
        wait_clock(16);
        wait until test_state = upper_test_read;
        assert rd_empty = '0'
            report "Fifo should not be empty by now"
            severity failure;
        wait_clock(1);
        while true loop
            if rd_empty = '0' then
                read_data(rd_data);
                fifo_rd_data := fifo.read;
                assert rd_data = fifo_rd_data
                    report "Data read: " & fo(rd_data) & ", expected " & fo(fifo_rd_data)
                    severity error;
            else
                wait until rd_clk = '1';
            end if;
        end loop;
    end process;

end async_fifo_tb;

