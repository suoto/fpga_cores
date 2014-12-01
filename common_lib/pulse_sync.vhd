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
entity pulse_sync is
    generic (
        EXTRA_DELAY_CYCLES : natural := 1
    );
    port (
        -- Usual ports
        src_clk     : in  std_logic;
        src_clken   : in  std_logic;
        src_pulse   : in  std_logic;

        dst_clk     : in  std_logic; 
        dst_clken   : in  std_logic;
        dst_pulse   : out std_logic
    );
end pulse_sync;

architecture pulse_sync of pulse_sync is

    -----------
    -- Types --
    -----------

    -------------
    -- Signals --
    -------------
    signal pulse_toggle : std_logic := '0';

begin

    -------------------
    -- Port mappings --
    -------------------
    dst_pulse_t : entity common_lib.edge_detector
        generic map (
            SYNCHRONIZE_INPUT => true,
            OUTPUT_DELAY      => EXTRA_DELAY_CYCLES
            )
        port map (
            -- Usual ports
            clk     => dst_clk,
            clken   => dst_clken,

            -- 
            din     => pulse_toggle,
            -- Edges detected
            rising  => open, 
            falling => open, 
            toggle  => dst_pulse
        );

    -----------------------------
    -- Asynchronous asignments --
    -----------------------------

    ---------------
    -- Processes --
    ---------------
    process(src_clk)
    begin
        if src_clk'event and src_clk = '1' then
            if src_clken = '1' then
                if src_pulse = '1' then
                    pulse_toggle <= not pulse_toggle;
                end if;
            end if;
        end if;
    end process;

end pulse_sync;


