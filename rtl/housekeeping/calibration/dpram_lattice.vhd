library ieee;
library ECP5U;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ECP5U.components.all;


entity dp_ram_rbw_scl is
  generic (
    DATA_WIDTH : integer := 72;
    ADDR_WIDTH : integer := 10
    );
  port (
-- common clock
    clk    : in  std_logic;
    -- Port A
    we_a   : in  std_logic;
    addr_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    data_a : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    q_a    : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Port B
    we_b   : in  std_logic;
    addr_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    data_b : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    q_b    : out std_logic_vector(DATA_WIDTH-1 downto 0)    );
end dp_ram_rbw_scl;

architecture behave of dp_ram_rbw_scl is
  signal r_addr_a,r_addr_b : std_logic_vector(13 downto 0) := "00000000000000";
  signal scuba_vhi: std_logic;
  signal scuba_vlo: std_logic;

  
  attribute NGD_DRC_MASK : integer;
  attribute NGD_DRC_MASK of behave : architecture is 1;

  
begin

  scuba_vhi_inst: VHI
    port map (Z=>scuba_vhi);

  scuba_vlo_inst: VLO
    port map (Z=>scuba_vlo);

    

  g0: for i in 0 to ADDR_WIDTH-1 generate
    r_addr_a(4+i) <= addr_a(i);
    r_addr_b(4+i) <= addr_b(i);
  end generate g0;
  g1: for i in ADDR_WIDTH to 13-4 generate
    r_addr_a(4+i) <= scuba_vlo;
    r_addr_b(4+i) <= scuba_vlo;
  end generate g1;
  r_addr_a(3 downto 0) <= (scuba_vlo, scuba_vlo, scuba_vhi, scuba_vhi);
  r_addr_b(3 downto 0) <= (scuba_vlo, scuba_vlo, scuba_vhi, scuba_vhi);
  
  
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

  ram1 : DP16KD
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
              DIA15 => data_a(31),
              DIA14 => data_a(30),
              DIA13 => data_a(29),
              DIA12 => data_a(28),
              DIA11 => data_a(27),
              DIA10 => data_a(26),
              DIA9 => data_a(25),
              DIA8 => data_a(24),
              DIA7 => data_a(23),
              DIA6 => data_a(22),
              DIA5 => data_a(21),
              DIA4 => data_a(20),
              DIA3 => data_a(19),
              DIA2 => data_a(18),
              DIA1 => data_a(17),
              DIA0 => data_a(16),
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
              DIB15 => data_b(31),
              DIB14 => data_b(30),
              DIB13 => data_b(29),
              DIB12 => data_b(28),
              DIB11 => data_b(27),
              DIB10 => data_b(26),
              DIB9 => data_b(25),
              DIB8 => data_b(24),
              DIB7 => data_b(23),
              DIB6 => data_b(22),
              DIB5 => data_b(21),
              DIB4 => data_b(20),
              DIB3 => data_b(19),
              DIB2 => data_b(18),
              DIB1 => data_b(17),
              DIB0 => data_b(16),
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
              DOA15 => q_a(31),
              DOA14 => q_a(30),
              DOA13 => q_a(29),
              DOA12 => q_a(28),
              DOA11 => q_a(27),
              DOA10 => q_a(26),
              DOA9 => q_a(25),
              DOA8 => q_a(24),
              DOA7 => q_a(23),
              DOA6 => q_a(22),
              DOA5 => q_a(21),
              DOA4 => q_a(20),
              DOA3 => q_a(19),
              DOA2 => q_a(18),
              DOA1 => q_a(17),
              DOA0 => q_a(16),
              DOB17 => open,
              DOB16 => open,
              DOB15 => q_b(31),
              DOB14 => q_b(30),
              DOB13 => q_b(29),
              DOB12 => q_b(28),
              DOB11 => q_b(27),
              DOB10 => q_b(26),
              DOB9 => q_b(25),
              DOB8 => q_b(24),
              DOB7 => q_b(23),
              DOB6 => q_b(22),
              DOB5 => q_b(21),
              DOB4 => q_b(20),
              DOB3 => q_b(19),
              DOB2 => q_b(18),
              DOB1 => q_b(17),
              DOB0 => q_b(16)
              );
  

  
end behave;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dp_ram_scl is
  generic (
    DATA_WIDTH : integer := 72;
    ADDR_WIDTH : integer := 10
    );
  port (
-- common clock
    clk    : in  std_logic;
    -- Port A
    we_a   : in  std_logic;
    addr_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    data_a : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    q_a    : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Port B
    we_b   : in  std_logic;
    addr_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    data_b : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    q_b    : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end dp_ram_scl;

architecture behave of dp_ram_scl is
  -- Shared memory
  type mem_type is array ((2**ADDR_WIDTH)-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mem : mem_type;
  --attribute syn_ramstyle : string;
  --attribute syn_ramstyle of mem : signal is "block_ram";

  
begin

  process(clk) is
  begin
    if rising_edge(clk) then
      if(we_a = '1') then
        q_a <= data_a;
        mem(to_integer(unsigned(addr_a))) <= data_a;
      else
        q_a <= mem(to_integer(unsigned(addr_a)));
      end if;
      
      if(we_b = '1') then
        q_b <= data_b;
        mem(to_integer(unsigned(addr_b))) <= data_b;
      else
        q_b <= mem(to_integer(unsigned(addr_b)));
      end if;
    end if;
  end process;
end behave;
