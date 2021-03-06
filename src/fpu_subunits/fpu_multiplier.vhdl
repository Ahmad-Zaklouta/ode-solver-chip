library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

entity fpu_multiplier is
	port (
		mode  : in std_logic_vector(1 downto 0);
		clk   : in std_logic;
		rst   : in std_logic;
		enbl  : in std_logic;
		in_a  : in std_logic_vector(63 downto 0);
		in_b  : in std_logic_vector(63 downto 0);

		out_c : out std_logic_vector(63 downto 0);
		done  : out std_logic;
		err   : out std_logic;
		zero  : out std_logic;
		posv  : out std_logic
	);
end entity;

-- Multiplier implementation with operators
-- Used by other components temporarily until other algos architectures are done
architecture with_operators of fpu_multiplier is
	constant SCALE_FACTOR : integer   := 7;  -- fixed point fixed scale factor
	constant SIZE         : integer   := 16; -- fixed point operands' SIZE

	signal error          : std_logic := '0';
begin
	process (in_a, in_b, clk, rst, enbl)
		variable output               : std_logic_vector(2 * SIZE - 1 downto 0);
		variable out64                : std_logic_vector(4 * SIZE - 1 downto 0);
		variable zero_flag			  : std_logic;
		variable error_local          : std_logic := error;
		variable multiplier           : std_logic_vector(SIZE downto 0);
	begin
		-- these initializations are for reset and enable 
		-- when enbl is 0 all outputs except err are reset , when rst is 1 all outputs are reset
		if (rst = '1') then -- reset signal
			zero  <= '0';
			posv  <= '0';
			done  <= '1';
			error <= '0';
			err   <= '0';
			out_c  <= (others => '0');
		elsif enbl = '0' then
			zero  <= '0';
			posv  <= '0';
			done  <= '0';
			err   <= error;
			out_c  <= (others => '0');
		elsif (enbl = '1' and error = '0' and rising_edge(clk)) then -- enabled 
			output := (others => '0');
			out64  := (others => '0');
			multiplier := (others => '0');
			zero_flag :='0';

			output(31 downto 0) := std_logic_vector(signed(in_a(15 downto 0)) * signed(in_b(15 downto 0))); -- fixed point multiplication output

			-- output signals 
			out64(SIZE - 1 downto 0) := output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR); -- taking the right bits

			error_local              := not((((output(31) and output(30)) and (output(29) and output(28))) and ((output(27) and output(26)) and (output(25) and output(24))) and (output(23) and output(22)))
				or not (((output(31) or output(30)) or (output(29) or output(28))) or ((output(27) or output(26)) or (output(25) or output(24))) or (output(23) or output(22))));
			-- overflow flag (error flag)
			out64(63 downto 16) := (others => output(31));                                -- extending the signbit

			if (unsigned(output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR)) = 0) then -- zero flag 
				zero_flag := '1';
			end if;
			
			err  <= error_local;
			error<= error_local;
			posv <= not output(SIZE - 1) and not zero_flag; -- positive output?
			zero <= zero_flag;
			done <= '1';
			out_c <= out64;
		end if;
	end process;
end architecture;


architecture first_algo of fpu_multiplier is
	constant SCALE_FACTOR : integer   := 7;  -- fixed point fixed scale factor
	constant SIZE         : integer   := 16; -- fixed point operands' SIZE

	signal error          : std_logic := '0';
begin
	process (in_a, in_b, clk, rst, enbl)
		variable output               : std_logic_vector(2 * SIZE - 1 downto 0);
		variable out64                : std_logic_vector(4 * SIZE - 1 downto 0);
		variable zero_flag			  : std_logic;
		variable error_local          : std_logic := error;
		variable multiplier           : std_logic_vector(SIZE downto 0);
	begin
		-- these initializations are for reset and enable 
		-- when enbl is 0 all outputs except err are reset , when rst is 1 all outputs are reset
		if (rst = '1') then -- reset signal
			zero  <= '0';
			posv  <= '0';
			done  <= '1';
			error <= '0';
			err   <= '0';
			out_c  <= (others => '0');
		elsif enbl = '0' then
			zero  <= '0';
			posv  <= '0';
			done  <= '0';
			err   <= error;
			out_c  <= (others => '0');
		elsif (enbl = '1' and error = '0' and rising_edge(clk)) then -- enabled 
			output := (others => '0');
			out64  := (others => '0');
			multiplier := (others => '0');
			zero_flag :='0';

			-- booth algorithm
			multiplier(SIZE downto 1) := in_b(SIZE - 1 downto 0);
			for i in 0 to SIZE - 1 loop
				if multiplier(i + 1 downto i) = "10" then                                                 -- subtract the multiplicand
					output(i + SIZE - 1 downto i) := output(i + SIZE - 1 downto i) - in_a(SIZE - 1 downto 0); -- use the implemented adder/subtractor when it's done
				elsif multiplier(i + 1 downto i) = "01" then                                              -- add the multiplicand
					output(i + SIZE - 1 downto i) := output(i + SIZE - 1 downto i) + in_a(SIZE - 1 downto 0); -- use the implemented adder/subtractor when it's done
				end if;
				output(i + SIZE) := output(i + SIZE - 1); -- extending the sign bit while shifting
			end loop;

			-- output signals 
			out64(SIZE - 1 downto 0) := output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR); -- taking the right bits

			error_local              := not((((output(31) and output(30)) and (output(29) and output(28))) and ((output(27) and output(26)) and (output(25) and output(24))) and (output(23) and output(22)))
				or not (((output(31) or output(30)) or (output(29) or output(28))) or ((output(27) or output(26)) or (output(25) or output(24))) or (output(23) or output(22))));
			-- overflow flag (error flag)
			out64(63 downto 16) := (others => output(31));                                -- extending the signbit

			if (unsigned(output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR)) = 0) then -- zero flag 
				zero_flag := '1';
			end if;
			
			err  <= error_local;
			error<= error_local;
			posv <= not output(SIZE - 1) and not zero_flag; -- positive output?
			zero <= zero_flag;
			done <= '1';
			out_c <= out64;
		end if;
	end process;
end architecture;

architecture sec_algo of fpu_multiplier is
	constant SCALE_FACTOR : integer   := 7;  -- fixed point fixed scale factor
	constant SIZE         : integer   := 16; -- fixed point operands' SIZE

	signal error          : std_logic := '0';
begin
	process (in_a, in_b, clk, rst, enbl)
		variable output , extended , complement     : std_logic_vector(2 * SIZE - 1 downto 0);
		variable out64                				: std_logic_vector(4 * SIZE - 1 downto 0);
		variable zero_flag			  				: std_logic;
		variable error_local          				: std_logic := error;
	begin
		-- these initializations are for reset and enable 
		-- when enbl is 0 all outputs except err are reset , when rst is 1 all outputs are reset
		if (rst = '1') then -- reset signal
			zero  <= '0';
			posv  <= '0';
			done  <= '1';
			error <= '0';
			err   <= '0';
			out_c  <= (others => '0');
		elsif enbl = '0' then
			zero  <= '0';
			posv  <= '0';
			done  <= '0';
			err   <= error;
			out_c  <= (others => '0');
		elsif (enbl = '1' and error = '0' and rising_edge(clk)) then -- enabled 
			output := (others => '0');
			out64  := (others => '0');
			zero_flag :='0';

			-- shift and add algorithm
			extended(2*SIZE - 1 downto size) := (others => in_a(SIZE - 1));
			extended(SIZE -1 downto 0)		 := in_a(SIZE - 1 downto 0);
			complement	:= (not extended) + 1;
			for i in 0 to SIZE - 2 loop
				if in_b(i) = '1' then 
					output(2*SIZE - 1 downto i) := output(2*SIZE - 1 downto i) + extended(2*SIZE - i - 1 downto 0);
				end if;
			end loop;
			if in_b(SIZE - 1) = '1' then 
				output(2*SIZE - 1 downto SIZE - 1) := output(2*SIZE - 1 downto SIZE - 1) + complement(SIZE downto 0);
			end if;
			
			-- output signals 
			out64(SIZE - 1 downto 0) := output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR); -- taking the right bits

			error_local              := not((((output(31) and output(30)) and (output(29) and output(28))) and ((output(27) and output(26)) and (output(25) and output(24))) and (output(23) and output(22)))
				or not (((output(31) or output(30)) or (output(29) or output(28))) or ((output(27) or output(26)) or (output(25) or output(24))) or (output(23) or output(22))));
			-- overflow flag (error flag)
			out64(63 downto 16) := (others => output(31));                                -- extending the signbit

			if (unsigned(output((SCALE_FACTOR + SIZE - 1) downto SCALE_FACTOR)) = 0) then -- zero flag 
				zero_flag := '1';
			end if;
			
			err  <= error_local;
			error<= error_local;
			posv <= not output(SIZE - 1) and not zero_flag; -- positive output?
			zero <= zero_flag;
			done <= '1';
			out_c <= out64;
		end if;
	end process;
end architecture;