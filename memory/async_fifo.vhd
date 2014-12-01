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
        -- FIFO configuration
        FIFO_LEN         : positive := 512;         -- FIFO length in number of positions
        UPPER_TRESHOLD   : natural  := 510;         -- FIFO level to assert wr_upper
        LOWER_TRESHOLD   : natural  := 10;          -- FIFO level to assert rd_lower
        DATA_WIDTH       : natural  := 8;           -- Data width
        -- FIFO config for error cases
        OVERFLOW_ACTION  : string   := "SATURATE";
        UNDERFLOW_ACTION : string   := "SATURATE"
    );
    port (
        -- Write port
        wr_clk      : in  std_logic;                                 -- Write clock
        wr_clken    : in  std_logic;                                 -- Write clock enable
        wr_rst      : in  std_logic;                                 -- Reset input at write clock
        wr_data     : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Fifo write data
        wr_en       : in  std_logic;                                 -- Fifo write enable
        wr_full     : out std_logic;                                 -- Fifo write full status
        wr_upper    : out std_logic;                                 -- Fifo write upper status

        -- Read port
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
    signal wr_ptr           : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal rd_ptr_at_wr_clk : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal ptr_diff_w       : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

    signal rd_ptr           : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal wr_ptr_at_rd_clk : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal ptr_diff_r       : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

    signal wr_ptr_gray      : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);
    signal rd_ptr_gray      : std_logic_vector(numbits(FIFO_LEN) - 1 downto 0);

    signal fifo_full_wr     : std_logic;
    signal fifo_empty_rd    : std_logic;

    signal error_wr         : std_logic;
    signal error_rd_wr      : std_logic;
    signal error_rd         : std_logic;
    signal error_wr_rd      : std_logic;


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

    wr_error_s : entity common_lib.pulse_sync
        generic map (
            EXTRA_DELAY_CYCLES => 0
            )
        port map (
            -- Usual ports
            src_clk     => wr_clk, 
            src_clken   => wr_clken, 
            src_pulse   => error_wr, 

            dst_clk     => rd_clk,
            dst_clken   => rd_clken,
            dst_pulse   => error_wr_rd
        );

    rd_error_s : entity common_lib.pulse_sync
        generic map (
            EXTRA_DELAY_CYCLES => 0
            )
        port map (
            -- Usual ports
            src_clk     => rd_clk, 
            src_clken   => rd_clken, 
            src_pulse   => error_rd, 

            dst_clk     => wr_clk,
            dst_clken   => wr_clken,
            dst_pulse   => error_rd_wr
        );
    -----------------------------
    -- Asynchronous asignments --
    -----------------------------
    ptr_diff_w      <= wr_ptr - rd_ptr_at_wr_clk;
    ptr_diff_r      <= wr_ptr_at_rd_clk - rd_ptr;

    fifo_full_wr    <= '1' when ptr_diff_w = FIFO_LEN - 1 else '0';
    fifo_empty_rd   <= '1' when ptr_diff_r = 0 else '0';

    wr_full         <= fifo_full_wr;
    rd_empty        <= fifo_empty_rd;

    ---------------
    -- Processes --
    ---------------
    process(wr_clk)
    begin
        if wr_clk'event and wr_clk = '1' then
            if wr_clken = '1' then

                -- Get the binary value of the read pointer inside the write clock
                rd_ptr_at_wr_clk <= gray_to_bin(rd_ptr_gray);
                wr_ptr_gray      <= bin_to_gray(wr_ptr);

                wr_upper <= '0';
                if ptr_diff_w >= UPPER_TRESHOLD then
                    wr_upper <= '1';
                end if;

                error_wr <= '0';
                if wr_en = '1' then
                    if OVERFLOW_ACTION = "SATURATE" and fifo_full_wr = '0' then
                        wr_ptr <= wr_ptr + 1;
                    elsif OVERFLOW_ACTION = "RESET" then
                        if fifo_full_wr = '0' then
                            wr_ptr <= wr_ptr + 1;
                            else
                            error_wr <= '1';
                            wr_ptr <= (others => '0');
                        end if;
                    end if;
                end if;

                if wr_rst = '1' or error_rd_wr = '1' then
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
                wr_ptr_at_rd_clk    <= gray_to_bin(wr_ptr_gray);

                rd_ptr_gray <= bin_to_gray(rd_ptr);

                rd_lower <= '0';
                if ptr_diff_r <= LOWER_TRESHOLD then
                    rd_lower <= '1';
                end if;

                rd_dv    <= '0';
                error_rd <= '0';
                if rd_en = '1' then
                    if UNDERFLOW_ACTION = "SATURATE" and fifo_empty_rd = '0' then
                        rd_dv  <= '1';
                        rd_ptr <= rd_ptr + 1;
                    elsif UNDERFLOW_ACTION = "RESET" then
                        if fifo_empty_rd = '0' then
                            rd_dv  <= '1';
                            rd_ptr <= rd_ptr + 1;
                            else
                            error_rd <= '1';
                            rd_ptr <= (others => '0');
                        end if;
                    end if;
                end if;
                if rd_rst = '1' or error_wr_rd = '1' then
                    rd_ptr <= (others => '0');
                end if;
            end if;
        end if;
    end process;
end async_fifo;



