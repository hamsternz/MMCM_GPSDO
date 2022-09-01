----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.08.2022 19:58:34
-- Design Name: 
-- Module Name: top - Behavioral
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


entity top is
    Port ( CLK100MHZ : in  STD_LOGIC;
           JB0       : in  STD_LOGIC;
           sw        : in  STD_LOGIC_VECTOR (15 downto 0);
           LED       : out STD_LOGIC_VECTOR (15 downto 0));
end top;

architecture Behavioral of top is

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
    signal clk   : std_logic;
begin

i_gps_xo: gps_xo generic map (
        clk_ext_freq => 100*1000*1000
    ) Port map ( 
        clk_ext  => CLK100MHZ,
        clk      => clk,
        pps      => JB0,
        trim     => LED,
        locked   => open
    );

end Behavioral;