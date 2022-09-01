------------------------------------------------------------------------------
-- Example of a GPS Disciplined XO using MMCM fine phase shift.
--
-- AUthor: Mike Field <hamster@snap.net.nz>
--
-- Can tune the XO of a BASYS3 development board to around 1ppm.
-- With a more stable XO, accuracy will be improved.
--
-- Fine phase shift is 1/32th of the VCO's 1.66ns period, or about 72ps. If the 
-- the VCO runs faster this will be less - at 1200MHz the steps are 36ps. So  
-- thisis fine for timing intervals, but not so great if you are driving DACs 
-- or ADCs.
------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity gps_xo is
    generic (
        clk_ext_freq : natural
    );
    Port ( clk_ext : in  STD_LOGIC;
           clk     : out STD_LOGIC;
           pps     : in  STD_LOGIC;
           trim    : out STD_LOGIC_VECTOR (15 downto 0);
           locked  : out STD_LOGIC);
end gps_xo;

architecture Behavioral of gps_xo is
    -- The control loop gain. A value of 192 here will be unstable.
    -- as error of 1Hz causes a 1Hz frequency change. Lower values 
    -- take longer to lock, A value of 4 gives 4/192 = 1/48 Hz change
    -- for each Hz or error, so is very mild, so will talk a long time
    -- to lock. BTW, 192 is 32*CLKOUT0_DIVIDE_F.
    constant loop_gain     : natural := 4;
    
    -- Limits to reject a new PPS pulse's error count (e.g. noise)
    constant max_count     : integer := clk_ext_freq + clk_ext_freq/1000;
    constant min_count     : integer := clk_ext_freq - clk_ext_freq/1000;

    -- We are locked when within 1ppm for four counts
    constant max_locked    : integer := clk_ext_freq + clk_ext_freq/1000000;
    constant min_locked    : integer := clk_ext_freq - clk_ext_freq/1000000;
    signal   locked_count  : unsigned(2 downto 0) := (others => '0');
    
    -- The Maximum error count that a single pulse can cause
    constant max_error     : integer := 4000;
    constant min_error     : integer := -4000;
    
    -- Limits that should never be hit - if you see these the 
    -- control loop is unstable or running in the wrong direction
    constant max_adjust    : signed(29 downto 0) := to_signed( 5000000,30);
    constant min_adjust    : signed(29 downto 0) := to_signed(-5000000,30);
    
    -- Clock signals for the MMCM
    signal new_clk         : std_logic;
    signal fb              : std_logic;

    -- For generating the phase shift pulses to the MMCM
    signal adjust          : signed(29 downto 0) := (others => '0');
    signal frac_error      : signed(29 downto 0) := (others => '0');
    signal psen            : std_logic := '0';
    signal psincdec        : std_logic := '0';

    -- error value conditioning pipeline, last_error is for external status
    signal error           : signed(29 downto 0) := (others => '0');
    signal clamped         : signed(29 downto 0) := (others => '0');
    signal last_error      : signed(29 downto 0) := (others => '0');

    -- For counting clocks between PPS pulses    
    signal counter         : signed(29 downto 0) := (others => '0');
    signal pps_unsafe      : std_logic := '0';
    signal pps_synced      : std_logic := '0';
    signal pps_synced_last : std_logic := '0';
    
    
begin
    clk      <= new_clk;

    trim     <= std_logic_vector(locked_count(2 downto 2)) & std_logic_vector(last_error(14 downto 0));
                 
    locked   <= '1' when locked_count(2) = '1' else '0';
    
process(new_clk)
    begin
        if rising_edge(new_clk) then
            
            -- The adjustments for the MMCM's VCO phase        
            if frac_error + adjust < 0 then
                psen     <= '1';
                psincdec <= '1';
                frac_error <= frac_error + adjust + clk_ext_freq/loop_gain; 
            elsif frac_error + adjust >= clk_ext_freq/loop_gain then
                psen     <= '1';
                psincdec <= '0';
                frac_error <= frac_error + adjust - clk_ext_freq/loop_gain; 
            else
                psen     <= '0';
                psincdec <= '0';
                frac_error <= frac_error + adjust;                 
            end if;
        
            -- Update the VCO's adjustments per second
            if adjust + clamped < min_adjust then
                adjust <= min_adjust;
            elsif adjust + clamped  > max_adjust then
                adjust <= max_adjust;
            else
                adjust <= adjust + clamped;
            end if;
            
            -- Don't allow it to change too quickly
            if error > max_error then
                clamped <= to_signed(max_error,clamped'length);
            elsif error < min_error then
                clamped <= to_signed(min_error,clamped'length);
            else
                clamped <= error;
            end if;

            -- Increment the count of cycles between PPS pulses            
            if counter <= max_count then            
                counter <= counter + 1;
            else
                locked_count <= (others => '0');            
            end if;

            -- Set the error and reset the counter if a pulse has arived
            error <= (others => '0');
            if pps_synced = '1' and pps_synced_last = '0' then
                if counter >= min_count and counter <= max_count then
                    error      <= signed((clk_ext_freq-1) - counter);
                    last_error <= signed((clk_ext_freq-1) - counter);
                end if;
                
                -- See if we are within the limits to to be locked
                if counter >= min_locked and counter <= max_locked then
                    if locked_count < 4 then
                        locked_count <= locked_count+1;
                    end if;
                else
                    locked_count <= (others => '0');
                end if;

                -- Start counting the cycles between PPS pulses again
                counter <= (others => '0');
            end if;
            
            -- synchronize the PPS
            pps_synced_last <= pps_synced;
            pps_synced      <= pps_unsafe;
            pps_unsafe      <= pps;
        end if;
    end process;

MMCME2_ADV_inst : MMCME2_ADV
   generic map (
      BANDWIDTH            => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
      CLKFBOUT_MULT_F      => 6.0,           -- Multiply value for all CLKOUT (2.000-64.000).
      CLKFBOUT_PHASE       => 0.0,           -- Phase offset in degrees of CLKFB (-360.000-360.000).
      -- CLKIN_PERIOD: Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      CLKIN1_PERIOD        => 0.0,
      CLKIN2_PERIOD        => 0.0,
      -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for CLKOUT (1-128)
      CLKOUT1_DIVIDE       => 1,
      CLKOUT2_DIVIDE       => 1,
      CLKOUT3_DIVIDE       => 1,
      CLKOUT4_DIVIDE       => 1,
      CLKOUT5_DIVIDE       => 1,
      CLKOUT6_DIVIDE       => 1,
      CLKOUT0_DIVIDE_F     => 6.0,          -- Divide amount for CLKOUT0 (1.000-128.000).
      -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for CLKOUT outputs (0.01-0.99).
      CLKOUT0_DUTY_CYCLE   => 0.5,
      CLKOUT1_DUTY_CYCLE   => 0.5,
      CLKOUT2_DUTY_CYCLE   => 0.5,
      CLKOUT3_DUTY_CYCLE   => 0.5,
      CLKOUT4_DUTY_CYCLE   => 0.5,
      CLKOUT5_DUTY_CYCLE   => 0.5,
      CLKOUT6_DUTY_CYCLE   => 0.5,
      -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for CLKOUT outputs (-360.000-360.000).
      CLKOUT0_PHASE        => 0.0,
      CLKOUT1_PHASE        => 0.0,
      CLKOUT2_PHASE        => 0.0,
      CLKOUT3_PHASE        => 0.0,
      CLKOUT4_PHASE        => 0.0,
      CLKOUT5_PHASE        => 0.0,
      CLKOUT6_PHASE        => 0.0,
      CLKOUT4_CASCADE      => FALSE,           -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
      COMPENSATION         => "ZHOLD",        -- ZHOLD, BUF_IN, EXTERNAL, INTERNAL
      DIVCLK_DIVIDE        => 1,               -- Master division value (1-106)
      -- REF_JITTER: Reference input jitter in UI (0.000-0.999).
      REF_JITTER1          => 0.0,
      REF_JITTER2          => 0.0,
      STARTUP_WAIT         => FALSE,          -- Delays DONE until MMCM is locked (FALSE, TRUE)
      -- Spread Spectrum: Spread Spectrum Attributes
      SS_EN                => "FALSE",        -- Enables spread spectrum (FALSE, TRUE)
      SS_MODE              => "CENTER_HIGH", -- CENTER_HIGH, CENTER_LOW, DOWN_HIGH, DOWN_LOW
      SS_MOD_PERIOD        => 10000,          -- Spread spectrum modulation period (ns) (VALUES)
      -- USE_FINE_PS: Fine phase shift enable (TRUE/FALSE)
      CLKFBOUT_USE_FINE_PS => FALSE,
      CLKOUT0_USE_FINE_PS  => TRUE,
      CLKOUT1_USE_FINE_PS  => FALSE,
      CLKOUT2_USE_FINE_PS  => FALSE,
      CLKOUT3_USE_FINE_PS  => FALSE,
      CLKOUT4_USE_FINE_PS  => FALSE,
      CLKOUT5_USE_FINE_PS  => FALSE,
      CLKOUT6_USE_FINE_PS  => FALSE
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0      => new_clk,        -- 1-bit output: CLKOUT0
      CLKOUT0B     => open,           -- 1-bit output: Inverted CLKOUT0
      CLKOUT1      => open,           -- 1-bit output: CLKOUT1
      CLKOUT1B     => open,           -- 1-bit output: Inverted CLKOUT1
      CLKOUT2      => open,           -- 1-bit output: CLKOUT2
      CLKOUT2B     => open,           -- 1-bit output: Inverted CLKOUT2
      CLKOUT3      => open,           -- 1-bit output: CLKOUT3
      CLKOUT3B     => open,           -- 1-bit output: Inverted CLKOUT3
      CLKOUT4      => open,           -- 1-bit output: CLKOUT4
      CLKOUT5      => open,           -- 1-bit output: CLKOUT5
      CLKOUT6      => open,           -- 1-bit output: CLKOUT6
      -- DRP Ports: 16-bit (each) output: Dynamic reconfiguration ports
      DO           => open,           -- 16-bit output: DRP data
      DRDY         => open,           -- 1-bit output: DRP ready
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT     => fb,             -- 1-bit output: Feedback clock
      CLKFBOUTB    => open,           -- 1-bit output: Inverted CLKFBOUT
      -- Status Ports: 1-bit (each) output: MMCM status ports
      CLKFBSTOPPED => open,           -- 1-bit output: Feedback clock stopped
      CLKINSTOPPED => open,           -- 1-bit output: Input clock stopped
      LOCKED       => open,           -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock inputs
      CLKIN1       => clk_ext,        -- 1-bit input: Primary clock
      CLKIN2       => '0',            -- 1-bit input: Secondary clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      CLKINSEL     => '1',            -- 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
      PWRDWN       => '0',            -- 1-bit input: Power-down
      RST          => '0',            -- 1-bit input: Reset
      -- DRP Ports: 7-bit (each) input: Dynamic reconfiguration ports
      DADDR        => (others =>'0'), -- 7-bit input: DRP address
      DCLK         => '0',            -- 1-bit input: DRP clock
      DEN          => '0',            -- 1-bit input: DRP enable
      DI           => (others =>'0'), -- 16-bit input: DRP data
      DWE          => '0',            -- 1-bit input: DRP write enable
      -- Dynamic Phase Shift Ports: 1-bit (each) input: Ports used for dynamic phase shifting of the outputs
      PSCLK        => new_clk,        -- 1-bit input: Phase shift clock
      PSEN         => psen,           -- 1-bit input: Phase shift enable
      PSINCDEC     => psincdec,       -- 1-bit input: Phase shift increment/decrement
      -- Dynamic Phase Shift Ports: 1-bit (each) output: Ports used for dynamic phase shifting of the outputs
      PSDONE       => open,           -- 1-bit output: Phase shift done
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN      => fb              -- 1-bit input: Feedback clock
   );

end Behavioral;