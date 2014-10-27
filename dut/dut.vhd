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

entity dut is
end dut;

architecture dut of dut is

    constant CLK_PERIOD : time := 4 ns;

    signal clk  : std_logic := '0';

    signal din  : std_logic_vector(7 downto 0);
    signal dout : std_logic_vector(7 downto 0);

begin
    
    clk <= not clk after CLK_PERIOD/2;

    sr_delay_u : entity common_lib.synchronizer
        generic map (
            SYNC_STAGES => 3,
            DATA_WIDTH  => 8
        )
        port map (
            clk     => clk,
            clken   => '1',

            din     => din,
            dout    => dout
        );

    process
    begin
        din <= (others => '0');
        wait for 1 us;
        while true loop
            wait until clk = '1';
            wait until clk = '1';
            wait until clk = '1';
            din <= din + 1;
        end loop;
        wait;
    end process;


end dut;

