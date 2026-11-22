--------------------------------------------------------------------------------
-- 4-bit ALU with 8 operations
-- Board: Xilinx Spartan-3AN Starter Kit (XC3S700AN-FGG484)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ============================================================================
-- 1: ENTITY 
-- ============================================================================
entity ula_simples is
    generic (
        -- Debounce time in clock cycles: 1_000_000 x 20 ns = 20 ms.
        -- The testbench uses a small value so the simulation runs fast.
        DEBOUNCE_MAX : integer := 1_000_000
    );
    port (
        CLK     : in  std_logic;                     -- 50 MHz board clock
        SW      : in  std_logic_vector(3 downto 0);  -- 4 slide switches
        BTN_OK  : in  std_logic;                     -- confirm button (BTN_SOUTH)
        BTN_RST : in  std_logic;                     -- reset button (BTN_WEST)
        LED     : out std_logic_vector(7 downto 0)   -- 8 LEDs
    );
end ula_simples;

-- ============================================================================
-- 2: ARCHITECTURE 
-- ============================================================================
architecture behavior of ula_simples is

    -- ---------- Synchronizer signals ----------
    signal ok_s1, ok_s2   : std_logic := '0';  -- BTN_OK after 1 and 2 FFs
    signal rst_s1, rst_s2 : std_logic := '0';  -- BTN_RST after 1 and 2 FFs

    -- ---------- Debounce signals ----------
    signal counter    : integer range 0 to DEBOUNCE_MAX := 0;
    signal btn_clean  : std_logic := '0';  -- button without bounce
    signal btn_old    : std_logic := '0';  -- value in the previous clock
    signal btn_press  : std_logic;         -- '1' during ONE clock per press

    -- ---------- State machine ----------
    type state_type is (WAIT_OP, WAIT_A, WAIT_B, SHOW_RESULT);
    signal state : state_type := WAIT_OP;

    -- ---------- Stored values ----------
    signal op : std_logic_vector(2 downto 0) := "000";
    signal a  : std_logic_vector(3 downto 0) := "0000";
    signal b  : std_logic_vector(3 downto 0) := "0000";

    -- ---------- ALU outputs ----------
    signal result : std_logic_vector(3 downto 0);
    signal z, n, c, v : std_logic;

begin

    -- ========================================================================
    -- 1a: SYNCHRONIZER
    -- The buttons are not synchronized with the clock. Passing them through
    -- two flip-flops avoids metastability (an undefined level when the input
    -- changes exactly at the clock edge).
    -- ========================================================================
    process (CLK)
    begin
        if rising_edge(CLK) then
            ok_s1  <= BTN_OK;
            ok_s2  <= ok_s1;
            rst_s1 <= BTN_RST;
            rst_s2 <= rst_s1;
        end if;
    end process;

    -- ========================================================================
    -- 1b: DEBOUNCE + EDGE DETECTOR
    -- The button only counts as changed after staying stable for
    -- DEBOUNCE_MAX clock cycles (20 ms on the board).
    -- ========================================================================
    process (CLK)
    begin
        if rising_edge(CLK) then
            if ok_s2 = btn_clean then
                counter <= 0;                      -- no change: reset counter
            elsif counter = DEBOUNCE_MAX then
                btn_clean <= ok_s2;                -- stable long enough: accept
                counter   <= 0;
            else
                counter <= counter + 1;            -- still counting
            end if;
            btn_old <= btn_clean;                  -- remember last value
        end if;
    end process;

    -- Rising edge: pressed now AND not pressed in the previous clock
    btn_press <= btn_clean and not btn_old;

    -- ========================================================================
    -- 2: STATE MACHINE
    -- Each button press saves the switches and moves to the next state.
    -- ========================================================================
    process (CLK)
    begin
        if rising_edge(CLK) then
            if rst_s2 = '1' then                   -- reset
                state <= WAIT_OP;
                op    <= "000";
                a     <= "0000";
                b     <= "0000";
            elsif btn_press = '1' then
                case state is
                    when WAIT_OP =>
                        op    <= SW(2 downto 0);   -- 8 ops need only 3 bits
                        state <= WAIT_A;
                    when WAIT_A =>
                        a     <= SW;
                        state <= WAIT_B;
                    when WAIT_B =>
                        b     <= SW;
                        state <= SHOW_RESULT;
                    when SHOW_RESULT =>
                        state <= WAIT_OP;          -- start a new operation
                end case;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- 3: ALU (combinational)
    -- ========================================================================
    process (op, a, b)
        variable sum : unsigned(4 downto 0);       -- 5 bits: bit 4 = carry
        variable r   : std_logic_vector(3 downto 0);
    begin
        -- default values (avoid latches)
        r := "0000";
        c <= '0';
        v <= '0';

        case op is
            when "000" =>                          -- ADD
                sum := unsigned('0' & a) + unsigned('0' & b);
                r   := std_logic_vector(sum(3 downto 0));
                c   <= sum(4);
                -- overflow: same sign in, different sign out
                if a(3) = b(3) and r(3) /= a(3) then
                    v <= '1';
                end if;

            when "001" =>                          -- SUB: A + (not B) + 1
                sum := unsigned('0' & a) + unsigned('0' & not b) + 1;
                r   := std_logic_vector(sum(3 downto 0));
                c   <= sum(4);                     -- 1 = no borrow
                -- overflow: different signs in, result sign differs from A
                if a(3) /= b(3) and r(3) /= a(3) then
                    v <= '1';
                end if;

            when "010" => r := a and b;            -- AND
            when "011" => r := a or b;             -- OR
            when "100" => r := a xor b;            -- XOR
            when "101" => r := not a;              -- NOT A

            when "110" =>                          -- SHIFT LEFT
                r := a(2 downto 0) & '0';
                c <= a(3);                         -- bit shifted out

            when others =>                         -- "111": SHIFT RIGHT
                r := '0' & a(3 downto 1);
                c <= a(0);                         -- bit shifted out
        end case;

        result <= r;
        n      <= r(3);                            -- sign bit
        if r = "0000" then z <= '1'; else z <= '0'; end if;
    end process;

    -- ========================================================================
    -- 4: LEDs
    -- At the end:   flags + result.
    -- ========================================================================
    process (state, SW, z, n, c, v, result)
    begin
        case state is
            when WAIT_OP     => LED <= "0001" & SW;
            when WAIT_A      => LED <= "0010" & SW;
            when WAIT_B      => LED <= "0100" & SW;
            when SHOW_RESULT => LED <= z & n & c & v & result;
        end case;
    end process;

end behavior;
