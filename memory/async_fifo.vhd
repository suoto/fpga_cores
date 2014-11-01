---------------------------------
-- Block name and description --
--------------------------------

---------------
-- Libraries --
---------------
library	ieee;
    use ieee.std_logic_1164.all;  
    use ieee.std_logic_arith.all;			   
    use ieee.std_logic_unsigned.all;			   

library common_lib;
    use common_lib.common_pkg.all;

library memory;

------------------------
-- Entity declaration --
------------------------
entity async_fifo is
    generic (
        FIFO_LEN        : positive := 512;
        UPPER_TRESHOLD  : natural  := 510;
        LOWER_TRESHOLD  : natural  := 10;
        DATA_WIDTH      : natural  := 8
    );
    port (
        -- Write port
        wr_clk      : in  std_logic;
        wr_clken    : in  std_logic;
        wr_rst      : in  std_logic;
        wr_data     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        wr_en       : in  std_logic;
        wr_full     : out std_logic;
        wr_upper    : out std_logic;

        rd_clk      : in  std_logic;
        rd_clken    : in  std_logic;
        rd_rst      : in  std_logic;
        rd_data     : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        rd_en       : in  std_logic;
        rd_dv       : out std_logic;
        rd_lower    : out std_logic;
        rd_empty    : out std_logic
    );
end async_fifo;

architecture async_fifo of async_fifo is

    -----------
    -- Types --
    -----------


    -------------
    -- Signals --
    -------------
    signal wr_ptr   : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal wr_ptr_b : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal wr_ptr_r : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

    signal rd_ptr   : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal rd_ptr_b : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal rd_ptr_w : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

    signal ptr_diff_w : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal ptr_diff_r : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

begin

    -------------------
    -- Port mappings --
    -------------------
    mem : entity memory.ram_inference
        generic map (
            ADDR_WIDTH         => numbits(FIFO_LEN),
            DATA_WIDTH         => DATA_WIDTH,
            EXTRA_OUTPUT_DELAY => 0
            )
        port map (
            -- Port A
            clk_a     => wr_clk,
            clken_a   => wr_clken,
            wren_a    => wr_en, 
            addr_a    => wr_ptr, 
            wrdata_a  => wr_data, 
            rddata_a  => open,
    
            -- Port B
            clk_b     => rd_clk,
            clken_b   => rd_clken, 
            addr_b    => rd_ptr, 
            rddata_b  => rd_data 
        );

    -----------------------------
    -- Asynchronous asignments --
    -----------------------------
    wr_ptr_b <= gray_to_bin(wr_ptr);
    rd_ptr_b <= gray_to_bin(rd_ptr);
    
    ---------------
    -- Processes --
    ---------------
    process(wr_clk)
    begin
        if wr_clk'event and wr_clk = '1' then
            if wr_clken = '1' then
                -- Get the binary value of the read pointer inside the write clock
                rd_ptr_w    <= gray_to_bin(rd_ptr);
                ptr_diff_w  <= gray_to_bin(wr_ptr) - rd_ptr_w;

                wr_upper <= '0';
                if ptr_diff_w >= UPPER_TRESHOLD then
                    wr_upper <= '1';
                end if;

                if wr_en = '1' then
                    wr_ptr <= gray_inc(wr_ptr);
                end if;

                if wr_rst = '1' then
                    wr_ptr <= (others => '0');
                end if;
            end if;
        end if;
    end process;


    process(rd_clk)
    begin
        if rd_clk'event and rd_clk = '1' then
            if rd_clken = '1' then
                -- Get the binary value of the write pointer inside the read clock
                wr_ptr_r    <= gray_to_bin(wr_ptr);
                ptr_diff_r  <= wr_ptr_r - gray_to_bin(rd_ptr);
                
                rd_lower <= '0';
                if ptr_diff_r <= LOWER_TRESHOLD then
                    rd_lower <= '1';
                end if;

                if rd_en = '1' then
                    rd_ptr <= gray_inc(rd_ptr);
                end if;
                if rd_rst = '1' then
                    rd_ptr <= (others => '0');
                end if;
            end if;
        end if;
    end process;


end async_fifo;


