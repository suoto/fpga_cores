---------------------------------
-- Block name and description --
--------------------------------

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
entity entity_t is
    generic (
        DELAY_CYCLES : positive := 1;
        DATA_WIDTH   : integer  := 1);
    port (
        -- Usual ports
        clk     : in  std_logic;
        clken   : in  std_logic;
        rst     : in  std_logic;

        -- Block specifics
        din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity_t;

architecture entity_t of entity_t is

    -----------
    -- Types --
    -----------
    type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal din_sr   : din_t(DELAY_CYCLES - 1 downto 0);

begin

    -------------------
    -- Port mappings --
    -------------------

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------

    ---------------
    -- Processes --
    ---------------
    process(clk, rst)
    begin
        if rst = '1' then
            null;
        elsif clk'event and clk = '1' then
            if clken = '1' then

            end if;
        end if;
    end process;


end entity_t;


