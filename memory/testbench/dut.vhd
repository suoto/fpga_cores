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
    use work.tb_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

library common_lib;
    use common_lib.common_pkg.all;

library memory;

entity dut is
end dut;

architecture dut of dut is

    constant CLK_A_PERIOD : time := 4 ns;
    constant CLK_B_PERIOD : time := 9 ns;

    constant ADDR_WIDTH         : positive := 16;
    constant DATA_WIDTH         : positive := 16;
    constant EXTRA_OUTPUT_DELAY : natural  := 0;

    signal clk_a     : std_logic := '0';
    signal clken_a   : std_logic;
    signal wren_a    : std_logic;
    signal addr_a    : std_logic_vector(ADDR_WIDTH - 1 downto 0);
    signal wrdata_a  : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rddata_a  : std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal clk_b     : std_logic := '0';
    signal clken_b   : std_logic;
    signal wren_b    : std_logic;
    signal addr_b    : std_logic_vector(ADDR_WIDTH - 1 downto 0);
    signal wrdata_b  : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rddata_b  : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

    clk_a <= not clk_a after CLK_A_PERIOD/2;
    clk_b <= not clk_b after CLK_B_PERIOD/2;
    process
    begin
        clken_a <= '0';
        for i in 0 to 3 loop
            wait until clk_a = '1';
        end loop;
        clken_a <= '1';
        wait until clk_a = '1';
    end process;
    clken_b <= '1';

    ram_u : entity memory.ram_inference
        generic map (
            ADDR_WIDTH         => ADDR_WIDTH,
            DATA_WIDTH         => ADDR_WIDTH,
            EXTRA_OUTPUT_DELAY => EXTRA_OUTPUT_DELAY
            )
        port map (
            -- Port A
            clk_a    => clk_a,
            clken_a  => clken_a,
            wren_a   => wren_a,
            addr_a   => addr_a,
            wrdata_a => wrdata_a,
            rddata_a => rddata_a,

            -- Port B
            clk_b    => clk_b,
            clken_b  => clken_b,
            wren_b   => wren_b,
            addr_b   => addr_b,
            wrdata_b => wrdata_b,
            rddata_b => rddata_b
        );

    port_a : process
        procedure write_data ( addr, data : in std_logic_vector) is
            begin
                wren_a   <= '1';
                addr_a   <= addr;
                wrdata_a <= data;
                wait until clk_a = '1' and clken_a = '1';
                wren_a <= '0';
            end procedure write_data;
        procedure write_data ( addr, data : in integer) is
            begin
                write_data( conv_std_logic_vector(addr, ADDR_WIDTH),
                            conv_std_logic_vector(data, DATA_WIDTH));
            end procedure write_data;

        procedure read_data ( addr : in std_logic_vector; data : out std_logic_vector) is
            begin
                addr_a  <= addr;
                wait until clk_a = '1' and clken_a = '1';
                data    := rddata_a;
            end procedure read_data;
    begin
        wren_a <= '0';
        for i in 0 to 10 loop
        wait until clk_a = '1' and clken_a = '1';
        end loop;
        for i in 0 to 10 loop
            write_data(i, i + 20);
            wait until clk_a = '1' and clken_a = '1';
        end loop;
        wait;
    end process;

    port_b : process
        procedure write_data ( addr, data : in std_logic_vector) is
            begin
                wren_b   <= '1';
                addr_b   <= addr;
                wrdata_b <= data;
                wait until clk_b = '1';
                wren_b <= '0';
            end procedure write_data;
        procedure write_data ( addr, data : in integer) is
            begin
                write_data( conv_std_logic_vector(addr, ADDR_WIDTH),
                            conv_std_logic_vector(data, DATA_WIDTH));
            end procedure write_data;

        procedure read_data ( addr : in std_logic_vector; data : out std_logic_vector) is
            begin
                addr_b  <= addr;
                wait until clk_b = '1';
                data    := rddata_b;
            end procedure read_data;
    begin
        wren_b    <= '0';
        addr_b    <= (others => '0');
        addr_b(2) <= '1';
        wait;
        for i in 0 to 10 loop
            wait until clk_b = '1';
        end loop;
        for i in 0 to 10 loop
            write_data(i, i + 20);
        end loop;
        wait;
    end process;


end dut;

