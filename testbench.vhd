--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:10:00 11/21/2016
-- Design Name:   
-- Module Name:   C:/UDPlus/testbench.vhd
-- Project Name:  UDPlus
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY testbench IS
END testbench;
 
ARCHITECTURE behavior OF testbench IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT top
    PORT(
         zcd_i : IN  std_logic;
         ocd_i : IN  std_logic;
         int_i : IN  std_logic;
         dip_sw_i : IN  std_logic_vector(7 downto 0);
         ot_i : IN  std_logic;
         uvlo_i : IN  std_logic;
         osc_i : IN  std_logic;
         pw_i : IN  std_logic;
         osc_o : INOUT  std_logic;
         pw_o : OUT  std_logic;
         mod_o : OUT  std_logic;
         fault_o : OUT  std_logic;
         gdt1a_o : OUT  std_logic;
         gdt1b_o : OUT  std_logic;
         gdt2a_o : OUT  std_logic;
         gdt2b_o : OUT  std_logic;
			tp1_o : out std_logic;
			tp2_o : out std_logic
        );
    END COMPONENT;
   
	constant fb_half_period : time := 525 ns;
--	constant fb_half_period : time := 1200 ns;
	constant osc_half_period : time := 31.25 ns;
	constant pw_lim_ena : std_logic := '1';
	constant freewheel_ena : std_logic := '1';
	constant invert : std_logic := '0';
	constant ot_ena : std_logic := '1';
	constant int_on : std_logic := '0';
	constant int_off : std_logic := '1';


   --Inputs
   signal zcd_i : std_logic := '0';
   signal ocd_i : std_logic := '0';
   signal int_i : std_logic := int_off;
   signal dip_sw_i : std_logic_vector(7 downto 0) := (others => '0');
   signal ot_i : std_logic := '0';
   signal uvlo_i : std_logic := '1';
   signal osc_i : std_logic := '0';
   signal pw_i : std_logic := '0';

 	--Outputs
   signal osc_o : std_logic;
   signal pw_o : std_logic;
   signal mod_o : std_logic;
   signal fault_o : std_logic;
   signal gdt1a_o : std_logic;
   signal gdt1b_o : std_logic;
   signal gdt2a_o : std_logic;
   signal gdt2b_o : std_logic; 
	signal tp1_o : std_logic;
	signal tp2_o : std_logic;
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top PORT MAP (
          zcd_i => zcd_i,
          ocd_i => ocd_i,
          int_i => int_i,
          dip_sw_i => dip_sw_i,
          ot_i => ot_i,
          uvlo_i => uvlo_i,
          osc_i => osc_i,
          pw_i => pw_i,
          osc_o => osc_o,
          pw_o => pw_o,
          mod_o => mod_o,
          fault_o => fault_o,
          gdt1a_o => gdt1a_o,
          gdt1b_o => gdt1b_o,
          gdt2a_o => gdt2a_o,
          gdt2b_o => gdt2b_o,
			 tp1_o => tp1_o,
			 tp2_o => tp2_o
        );

   -- Oscillator process definition
   process
   begin
		wait for osc_half_period;
		osc_i <= not osc_i;
--		if osc_o = '1' then
--			osc_i <= '1';
--		else
--			osc_i <= '0';
--			wait until osc_o = '1';
--		end if;
   end process;

   -- Feedback process definition
   process
   begin
		wait until gdt1a_o = '1';
		--while int_i = '1' or osc_o = '1' or osc_i = '1' loop
		while int_i = int_on or mod_o = '1' loop
			if invert = '1' then
				wait for fb_half_period;
			end if;
			zcd_i <= not zcd_i;	
			if invert = '0' then
				wait for fb_half_period;
			end if;
		end loop;
		zcd_i <= '0';
   end process;

   -- Stimulus process
   stim_proc: process
   begin		
		dip_sw_i <= pw_lim_ena & freewheel_ena & invert & ot_ena & "0001";
		ocd_i <= '0';
		uvlo_i <= '1';
	
      wait for 1 us;	
		
		int_i <= int_on;		
		wait for 5 us;
		ocd_i <= '1';
		wait for 5 us;		
		ocd_i <= '0';
		wait for 5 us;
		int_i <= int_off;
		
		wait for 5 us;

      -- insert stimulus here 
		int_i <= int_on;		
		wait for 10 us;
		int_i <= int_off;



      wait;
   end process;

END;
