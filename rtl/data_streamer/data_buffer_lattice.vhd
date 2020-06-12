--- Data buffer module, dual ported memory to store the sample data

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity data_buffer is
  generic (
    g_DATA_WIDTH : natural := 26;
    g_ADDRESS_WIDTH : natural := 11);
	port (
    -- Write port
		i_write_clk : in std_logic;
		i_write_enable : in std_logic;
		i_write_addr : in std_logic_vector(g_ADDRESS_WIDTH-2 downto 0);
		i_write_data : in std_logic_vector(2*g_DATA_WIDTH-1 downto 0);
    -- Read port
		i_read_clk : in std_logic;
		i_read_enable: in std_logic;
		i_read_addr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
		o_read_data : out std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0')
	);
end data_buffer;

architecture behavioral of data_buffer is

  signal r_read_addr : integer range 2 ** (g_ADDRESS_WIDTH - 1) - 1 downto 0;
  signal r_read_data : std_logic_vector(2 * g_DATA_WIDTH-1 downto 0);

  
begin

  ram0 : DP16KD
    generic map (INIT_DATA => "STATIC",
                 ASYNC_RESET_RELEASE => "SYNC",
                 CSDECODE_B => "0b000", CSDECODE_A => "0b000",
                 WRITEMODE_A => "READBEFOREWRITE", WRITEMODE_B => "READBEFOREWRITE",
                 GSR => "ENABLED",
                 RESETMODE => "ASYNC",
                 REGMODE_A => "NOREG", REGMODE_B => "NOREG",
                 DATA_WIDTH_A => 18, DATA_WIDTH_B => 18)
    port map (DIA17 => scuba_vlo,
              DIA16 => scuba_vlo,
              DIA15 => data_a(15),
              DIA14 => data_a(14),
              DIA13 => data_a(13),
              DIA12 => data_a(12),
              DIA11 => data_a(11),
              DIA10 => data_a(10),
              DIA9 => data_a(9),
              DIA8 => data_a(8),
              DIA7 => data_a(7),
              DIA6 => data_a(6),
              DIA5 => data_a(5),
              DIA4 => data_a(4),
              DIA3 => data_a(3),
              DIA2 => data_a(2),
              DIA1 => data_a(1),
              DIA0 => data_a(0),
              ADA13 => r_addr_a(13),
              ADA12 => r_addr_a(12),
              ADA11 => r_addr_a(11),
              ADA10 => r_addr_a(10),
              ADA9 => r_addr_a(9),
              ADA8 => r_addr_a(8),
              ADA7 => r_addr_a(7),
              ADA6 => r_addr_a(6),
              ADA5 => r_addr_a(5),
              ADA4 => r_addr_a(4),
              ADA3 => r_addr_a(3),
              ADA2 => r_addr_a(2),
              ADA1 => r_addr_a(1),
              ADA0 => r_addr_a(0),
              CEA => scuba_vhi,
              OCEA => scuba_vhi,
              CLKA => clk,
              WEA => we_a,
              CSA2 => scuba_vlo, CSA1 => scuba_vlo, CSA0 => scuba_vlo,
              RSTA => scuba_vlo,
              DIB17 => scuba_vlo,
              DIB16 => scuba_vlo,
              DIB15 => data_b(15),
              DIB14 => data_b(14),
              DIB13 => data_b(13),
              DIB12 => data_b(12),
              DIB11 => data_b(11),
              DIB10 => data_b(10),
              DIB9 => data_b(9),
              DIB8 => data_b(8),
              DIB7 => data_b(7),
              DIB6 => data_b(6),
              DIB5 => data_b(5),
              DIB4 => data_b(4),
              DIB3 => data_b(3),
              DIB2 => data_b(2),
              DIB1 => data_b(1),
              DIB0 => data_b(0),
              ADB13 => r_addr_b(13),
              ADB12 => r_addr_b(12),
              ADB11 => r_addr_b(11),
              ADB10 => r_addr_b(10),
              ADB9 => r_addr_b(9),
              ADB8 => r_addr_b(8),
              ADB7 => r_addr_b(7),
              ADB6 => r_addr_b(6),
              ADB5 => r_addr_b(5),
              ADB4 => r_addr_b(4),
              ADB3 => r_addr_b(3),
              ADB2 => r_addr_b(2),
              ADB1 => r_addr_b(1),
              ADB0 => r_addr_b(0),
              CEB => scuba_vhi,
              OCEB => scuba_vhi,
              CLKB => clk,
              WEB => we_b,
              CSB2 => scuba_vlo, CSB1 => scuba_vlo, CSB0 => scuba_vlo,
              RSTB => scuba_vlo,
              DOA17 => open,
              DOA16 => open,
              DOA15 => q_a(15),
              DOA14 => q_a(14),
              DOA13 => q_a(13),
              DOA12 => q_a(12),
              DOA11 => q_a(11),
              DOA10 => q_a(10),
              DOA9 => q_a(9),
              DOA8 => q_a(8),
              DOA7 => q_a(7),
              DOA6 => q_a(6),
              DOA5 => q_a(5),
              DOA4 => q_a(4),
              DOA3 => q_a(3),
              DOA2 => q_a(2),
              DOA1 => q_a(1),
              DOA0 => q_a(0),
              DOB17 => open,
              DOB16 => open,
              DOB15 => q_b(15),
              DOB14 => q_b(14),
              DOB13 => q_b(13),
              DOB12 => q_b(12),
              DOB11 => q_b(11),
              DOB10 => q_b(10),
              DOB9 => q_b(9),
              DOB8 => q_b(8),
              DOB7 => q_b(7),
              DOB6 => q_b(6),
              DOB5 => q_b(5),
              DOB4 => q_b(4),
              DOB3 => q_b(3),
              DOB2 => q_b(2),
              DOB1 => q_b(1),
              DOB0 => q_b(0));

  
  
end behavioral;
