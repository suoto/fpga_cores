-------------------------------
-- Shit register based delay --
-------------------------------

---------------
-- Libraries --
---------------
library	ieee;
    use ieee.std_logic_1164.all;  
    use ieee.std_logic_arith.all;			   
library common_lib;
    use common_lib.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity sr_delay is
    generic (
        DELAY_CYCLES : natural := 1;
        DATA_WIDTH   : positive := 1
        );
    port (
        clk     : in  std_logic;
        clken   : in  std_logic;

        din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end sr_delay;

architecture sr_delay of sr_delay is

    -----------
    -- Types --
    -----------
    type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal din_sr   : din_t(DELAY_CYCLES - 1 downto 0);

begin

    -----------------------------
    -- Asynchronous asignments --
    -----------------------------
    zd : if DELAY_CYCLES = 0 generate
        dout <= din;
    end generate zd;

    nzd : if DELAY_CYCLES > 0 generate
        dout <= din_sr(DELAY_CYCLES - 1);
    end generate nzd;

    ---------------
    -- Processes --
    ---------------
    nzd_p : if DELAY_CYCLES > 0 generate
        process(clk)
        begin
            if clk'event and clk = '1' then
                if clken = '1' then
                    din_sr  <= din_sr(DELAY_CYCLES - 2 downto 0) & din;
                end if;
            end if;
        end process;
    end generate nzd_p;


end sr_delay;

