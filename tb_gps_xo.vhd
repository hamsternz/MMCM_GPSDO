----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.09.2022 08:08:47
-- Design Name: 
-- Module Name: tb_gps_xo - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_gps_xo is
end tb_gps_xo;

architecture Behavioral of tb_gps_xo is
    component gps_xo is
    generic (
        clk_ext_freq : natural
    );
    Port ( clk_ext : in STD_LOGIC;
           clk     : out STD_LOGIC;
           pps     : in STD_LOGIC;
           trim    : out STD_LOGIC_VECTOR (15 downto 0);
           locked  : out STD_LOGIC);
    end component;
    signal clk_ext : STD_LOGIC;
    signal clk     : STD_LOGIC;
    signal pps     : STD_LOGIC := '0';
    signal trim    : STD_LOGIC_VECTOR (15 downto 0);
    signal locked  : STD_LOGIC;
begin

    
process
    begin
        clk_ext <= '1';
        wait for 5 ns;
        clk_ext <= '0';
        wait for 5 ns;
    end process;

process
    begin
        wait for 100000 ns;
        pps <= '1';
        wait for 100 ns;
        pps <= '0';
    end process;
    
i_gps_xo: gps_xo generic map (
        clk_ext_freq => 10000000
    ) Port map ( 
        clk_ext => clk_ext,
        clk     => clk,
        pps     => pps,
        trim    => trim,
        locked  => locked
    );

end Behavioral;
