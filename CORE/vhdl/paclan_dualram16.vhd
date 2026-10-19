library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pac-Land video read port A and CPU read/write port B.
-- Byte lane 0 is [7:0], lane 1 is [15:8].
entity paclan_dualram16 is
    generic (AW : positive := 12);
    port (
        clk : in std_logic;
        addr_a : in std_logic_vector(AW-1 downto 0);
        dout_a : out std_logic_vector(15 downto 0);
        addr_b : in std_logic_vector(AW-1 downto 0);
        din_b : in std_logic_vector(7 downto 0);
        we_b : in std_logic_vector(1 downto 0);
        dout_b : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of paclan_dualram16 is
    type ram_t is array (0 to 2**AW-1) of std_logic_vector(7 downto 0);
    signal lowram, highram : ram_t;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we_b(0) = '1' then
                lowram(to_integer(unsigned(addr_b))) <= din_b;
            end if;
            if we_b(1) = '1' then
                highram(to_integer(unsigned(addr_b))) <= din_b;
            end if;
            dout_a <= highram(to_integer(unsigned(addr_a))) & lowram(to_integer(unsigned(addr_a)));
            dout_b <= highram(to_integer(unsigned(addr_b))) & lowram(to_integer(unsigned(addr_b)));
        end if;
    end process;
end architecture;
