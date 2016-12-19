----------------------------------------------------------------------------------
-- Engineer:  Phillip Slawinski
-- 
-- Create Date:    17:48:01 11/20/2016 
-- Design Name:    
-- Module Name:    top - Behavioral 
-- Project Name: 	 UD+
-- Target Devices: xc9572xl-10vq44 / XC2C64A-7VQG44C
-- Tool versions: 
-- Description: Freewheeling DRSSTC driver with phase lead, UVLO, pulse limiting, 
--              and startup oscillator.
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
	Port ( 
		zcd_i : in std_logic; -- ZCD Feedback
		ocd_i : in std_logic; -- Overcurrent detect
		int_i : in std_logic; -- Interrupter
		dip_sw_i : in std_logic_vector (7 downto 0); -- Configuration DIP switch
		ot_i : in std_logic; -- Overtemperature detect
		uvlo_i : in std_logic; -- Undervoltage lockout
		osc_i : in std_logic; -- Start oscillator input
		pw_i : in std_logic; -- Pulse width limiter input
		osc_o : out std_logic; -- Start oscillator output
		pw_o : out std_logic; -- Pulse width limiter output
		mod_o : out std_logic; -- Gated interrupter LED
		fault_o : out std_logic; -- Fault indicator LED
		gdt1a_o : out std_logic; -- GDT 1 A output
		gdt1b_o : out std_logic; -- GDT 1 B output
		gdt2a_o : out std_logic; -- GDT 2 A output
		gdt2b_o : out std_logic;  -- GDT 2 B output
		tp1_o : out std_logic; -- Tespoint 1 Output
		tp2_o : out std_logic -- Tespoint 1 Output
	); 
end top;

architecture Behavioral of top is
	-- Declare attribute types
	attribute loc : string;
	attribute SCHMITT_TRIGGER : string;
	attribute SLEW : string;
	
	-- Assign pin locations to signals
	attribute loc of ot_i: signal is "P1";
	attribute loc of int_i: signal is "P2";
	attribute loc of uvlo_i: signal is "P5";
	attribute loc of ocd_i: signal is "P6";
	--attribute loc of zcd_i: signal is "P7"; -- XC9572XL
	attribute loc of zcd_i: signal is "P8"; -- XC2C64A
	attribute loc of dip_sw_i: signal is "P13 P14 P16 P18 P19 P20 P21 P22";
	attribute loc of gdt2b_o: signal is "P27";
	attribute loc of gdt2a_o: signal is "P28";
	attribute loc of gdt1b_o: signal is "P29";
	attribute loc of gdt1a_o: signal is "P30";
	attribute loc of tp2_o: signal is "P32";
	attribute loc of tp1_o: signal is "P33";
	attribute loc of osc_i: signal is "P39";
	attribute loc of osc_o: signal is "P40";
	attribute loc of pw_o: signal is "P41";
	attribute loc of pw_i: signal is "P42";
	attribute loc of fault_o: signal is "P43";
	attribute loc of mod_o: signal is "P44";
	
	-- Assign misc attributes to IO
	attribute SCHMITT_TRIGGER of osc_i: signal is "TRUE"; -- XC2C64A
	attribute SCHMITT_TRIGGER of pw_i: signal is "TRUE"; -- XC2C64A
	attribute SLEW of gdt1a_o: signal is "SLOW";
	attribute SLEW of gdt1b_o: signal is "SLOW";
	attribute SLEW of gdt2a_o: signal is "SLOW";
	attribute SLEW of gdt2b_o: signal is "SLOW";

	-- Gate drive ON/OFF constants
	constant GDT_ON : std_logic := '1';
	constant GDT_OFF : std_logic := '0';
	
	-- Startup oscillator count
	signal start_osc_cnt : std_logic_vector(4 downto 0) := (others => '0');
	
	-- Feedback signal
	signal fb_sig : std_logic := '0';
	
	-- Interrupter FF
	signal interrupter : std_logic := '0';

	-- Flag to indicate whether or not freewheeling is active
	signal freewheeling : std_logic := '0';

	-- Flag to indicate which side of the bridge to turn off when freewheeling
	signal fw_target : std_logic := '0';

	-- Number of startup clocks specified by the user + 1 (so that there is always one cycle of startup)
	signal num_start_clocks : std_logic_vector(4 downto 0) := (others => '0');
	
	-- OCD Interrupter disable flag
	signal ocd_interrupter_disable : std_logic := '0';
	
	-- Feedback valid registers
	signal fb_state_reg : std_logic_vector(3 downto 0) := "1000";
	
	-- Flag to indicate if we have valid feedback
	signal fb_valid : std_logic := '0';
	
	-- Start oscillator divider
	signal start_osc_div_2 : std_logic := '0';
	signal start_osc_div_4 : std_logic := '0';
	signal start_osc_div_8 : std_logic := '0';
	signal start_osc_div_16 : std_logic := '0';
	
	-- Global start oscillator clock
	signal start_osc : std_logic := '0';
	
	-- Flag to indicate whether or not there has been a feedback fault
	signal fb_fault : std_logic := '0';
	
	-- Flag to indicate that the maximum pulse width has been exceeded.
	signal pw_limit_exceeded : std_logic := '0';
	
	-- Flag to indicate that the UVLO has been tripped (will not reset until the unit is powered off)
	signal uvlo_fault : std_logic := '0';
	
	-- Flag to indicate that the Over-temp sensor has been tripped (will not reset until the unit is powered off)
	signal ot_fault : std_logic := '0';
	
	-- Flag to indicate that a fatal flaw has occured 
	signal fatal_fault : std_logic;
	
	-- Inverted interrupter signal (makes it active high)
	signal int : std_logic;
	
	-- Global feedback signal clock
	signal zcd : std_logic; 
	
	-- OCD registers
	signal ocd_tripped : std_logic := '0';
		
	-- Indicates that the start cycles are active
	signal start_cycles_active : boolean;
	
	-- Indicates that the start cycles are active
	signal start_cycles_reached : boolean;
	
	-- Selects feedback source (oscillator or ZCD in)
	signal fb_sel : std_logic := '0';
begin
		
	-- Get active high interrupter signal
	int <= not int_i;
		
	-- Assign number of start clocks
	num_start_clocks <= ("0" & dip_sw_i(3 downto 0)) + 1;
	
	-- Tie PW limiter to internal interrupter
	pw_o <= interrupter; 
	
	-- Run oscillator
	osc_o <= not osc_i; -- XC2C64A
	--osc_o <= 'Z'; -- XC9572XL
	
	-- Indicates that the last start cycle has been reached
	start_cycles_reached <= (start_osc_cnt >= dip_sw_i(3 downto 0));
	
	process(zcd_i, zcd, dip_sw_i)
	begin
		-- Set phase
		if dip_sw_i(5) = '1' then
			zcd <= not zcd_i;
		else
			zcd <= zcd_i;
		end if;
	end process;
	
	-- Derive startup signal
	process (osc_i)
	begin
		if rising_edge(osc_i) then
			start_osc_div_2 <= not start_osc_div_2;
		end if;
	end process;
	process(start_osc_div_2)
	begin
		if rising_edge(start_osc_div_2) then
			start_osc_div_4 <= not start_osc_div_4;
		end if;
	end process;
	process(start_osc_div_4)
	begin
		if rising_edge(start_osc_div_4) then
			start_osc_div_8 <= not start_osc_div_8;
			if interrupter = '1' then
				if not (fb_state_reg = "1111" or fb_state_reg = "0000") then
					--fb_state_reg(4) <= fb_state_reg(3);
					fb_state_reg(3) <= fb_state_reg(2);
					fb_state_reg(2) <= fb_state_reg(1);
					fb_state_reg(1) <= fb_state_reg(0);
					fb_state_reg(0) <= zcd;
				end if;
				
				-- If the feedback hasn't changed in three clocks, the feedback must be invalid
				if fb_state_reg = "1111" or fb_state_reg = "0000" then
					fb_valid <= '0';
				elsif zcd = '1' and start_cycles_reached then
					fb_valid <= '1';
				end if;
			else
				fb_state_reg <= "1000";
				fb_valid <= '0';
			end if;		
		end if;
	end process;
	process(start_osc_div_8)
	begin
		if rising_edge(start_osc_div_8) then
			start_osc_div_16 <= not start_osc_div_16;
		end if;
	end process;

	-- Global start oscillator clock
	start_osc <= start_osc_div_16;
	
	-- Output clock
	tp1_o <= start_osc_div_16;
	tp2_o <= ocd_tripped;
	
	-- Set UVLO fault (latching
	process (uvlo_i)
	begin
		if falling_edge(uvlo_i) then
			uvlo_fault <= '1';
		end if;
	end process;

	-- Set UVLO fault (non-latching)
	--uvlo_fault <= not uvlo_i;
	
	-- Set over-temp fault
	process (ot_i)
	begin
		if rising_edge(ot_i) then
			if dip_sw_i(4) = '1' then
				ot_fault <= '1';
			end if;
		end if;
	end process;
	
	-- Set fatal fault flag
	fatal_fault <= uvlo_fault or ot_fault;
	
	-- Boolean to indicate whether or not the start cycles elapsed
	start_cycles_active <= start_osc_cnt < num_start_clocks;
	
	-- Select feedback source
	process (start_osc, interrupter, fb_valid)
	begin
		if interrupter = '1' then
			if falling_edge(start_osc) then
				if start_cycles_active or fb_valid = '0' then
					fb_sel <= '0';
				else
					fb_sel <= '1';
				end if;			
			end if;
		else
			fb_sel <= '0';
		end if;
	end process;
	
	-- Mux feedback signal
	process (zcd, start_osc, fb_sel)
	begin
		if fb_sel = '0' then
			fb_sig <= start_osc;
		else
			fb_sig <= zcd;
		end if;
	end process;
	
	-- Handle OCD trip
	process (fb_sig, ocd_i)
	begin
		if ocd_i = '1' then
			ocd_tripped <= '1';
		else 
			if falling_edge(fb_sig) then
				-- Clear OCD
				ocd_tripped <= '0';
			end if;
		end if;
	end process;
	
	-- Generate gate drive signals
	process (fb_sig, ocd_i, int, zcd_i)
	begin		
		if rising_edge(fb_sig) then
			-- Check for feedback faults, and set interrupter
			if start_cycles_reached and fb_valid = '0' and int = '1' then
				fb_fault <= '1';
				interrupter <= '0';
			else
				-- Clock in interrupter state
				interrupter <= int and not fatal_fault;
				
				-- Reset if interrupter is off
				if int = '0' or fatal_fault = '1' then
					start_osc_cnt <= (others => '0');
					ocd_interrupter_disable <= '0';
					freewheeling <= '0';
					pw_limit_exceeded <= '0';
					--fb_valid <= '0';
				else
					-- Clear FB fault at the start of the interrupter pulse
					if fb_fault = '1' and start_osc_cnt = "00000" then
						fb_fault <= '0';
					end if;
				
					-- Increment start oscillator count
					if start_cycles_active then
						start_osc_cnt <= start_osc_cnt + 1;		
					end if;
					
					-- Overcurrent detect freewheeling enable
					if ocd_tripped = '1' then
						if dip_sw_i(6) = '0' then
							ocd_interrupter_disable <= '1';
							freewheeling <= '0';
						else
							freewheeling <= '1';
							fw_target <= not fw_target;				
						end if;
					else
						ocd_interrupter_disable <= '0';
						freewheeling <= '0';
					end if;
					
					-- PW Limiter signal
					pw_limit_exceeded <= (pw_i and dip_sw_i(7));				
				end if;			
			end if;								
		end if;
	end process;
	
	-- Set gate drive outputs
	process (freewheeling, interrupter, fw_target, fb_sig, pw_i, dip_sw_i, ocd_interrupter_disable, fb_fault, pw_limit_exceeded, fatal_fault)
	begin
		-- Indicate that the coil is freewheeling
		fault_o <= freewheeling or fb_fault or fatal_fault or pw_limit_exceeded or ocd_interrupter_disable;
		
		-- Indicate the interrupter status
		mod_o <= interrupter;
	
		-- Set GDT outputs
		if fatal_fault = '0' and interrupter = '1' and pw_limit_exceeded = '0' and ocd_interrupter_disable = '0' then
			if freewheeling = '1' then -- freewheeling, alternate sides of the bridge to turn off
				if fw_target = '0' then
					gdt1a_o <= fb_sig;
					gdt1b_o <= not fb_sig;
					gdt2a_o <= GDT_OFF;
					gdt2b_o <= GDT_OFF;								
				else
					gdt1a_o <= GDT_OFF;
					gdt1b_o <= GDT_OFF;								
					gdt2a_o <= fb_sig;
					gdt2b_o <= not fb_sig;
				end if;
			else -- Normal operation
				gdt1a_o <= fb_sig;
				gdt1b_o <= not fb_sig;
				gdt2a_o <= fb_sig;
				gdt2b_o <= not fb_sig;			
			end if;
		else -- Shut down
			gdt1a_o <= GDT_OFF;
			gdt1b_o <= GDT_OFF;
			gdt2a_o <= GDT_OFF;
			gdt2b_o <= GDT_OFF;
		end if;
	end process;

end Behavioral;