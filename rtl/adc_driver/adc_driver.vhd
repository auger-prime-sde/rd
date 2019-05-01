-- VHDL netlist generated by SCUBA Diamond (64-bit) 3.10.3.144.3
-- Module  Version: 5.8
--/usr/local/diamond/3.10_x64/ispfpga/bin/lin64/scuba -w -n adc_driver -lang vhdl -synth lse -bus_exp 7 -bb -arch sa5p00 -type iol -mode Receive -io_type LVDS -width 12 -freq_in 250 -gear 4 -eclk_bridge -del 128 -fdc /home/themba/synced/auger-radio-extension/rtl/adc_driver/adc_driver.fdc 

-- Wed May  1 11:10:44 2019


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library ecp5u;
use ecp5u.components.all;

entity adc_drivergddr_sync is
port(
  rst :  in std_logic;
  sync_clk :  in std_logic;
  start :  in std_logic;
  stop :  out std_logic;
  ddr_reset :  out std_logic;
  ready :  out std_logic);
end adc_drivergddr_sync;

architecture beh of adc_drivergddr_sync is
  signal STOP_ASSERT : std_logic_vector(2 downto 0);
  signal CS_GDDR_SYNC : std_logic_vector(1 to 1);
  signal CTRL_CNT : std_logic_vector(3 downto 0);
  signal CTRL_CNT_3 : std_logic_vector(3 downto 0);
  signal STOP_ASSERT_4 : std_logic_vector(2 downto 0);
  signal UN1_NS_GDDR_SYNC16 : std_logic_vector(0 to 0);
  signal CS_GDDR_SYNC_FAST : std_logic_vector(1 to 1);
  signal CTRL_CNT_3_MB_1 : std_logic_vector(1 downto 0);
  signal CS_GDDR_SYNC_QN : std_logic_vector(2 downto 0);
  signal CS_GDDR_SYNC_FAST_QN : std_logic_vector(1 to 1);
  signal CTRL_CNT_QN : std_logic_vector(3 downto 0);
  signal STOP_ASSERT_QN : std_logic_vector(2 downto 0);
  signal CS_GDDR_SYNC_RNO_1 : std_logic_vector(0 to 0);
  signal CS_GDDR_SYNC_RNO_0 : std_logic_vector(0 to 0);
  signal RESET_FLAG : std_logic ;
  signal DDR_RESET_D : std_logic ;
  signal UN1_NS_GDDR_SYNC36_1 : std_logic ;
  signal N_93 : std_logic ;
  signal N_79 : std_logic ;
  signal N_90 : std_logic ;
  signal CO0 : std_logic ;
  signal NS_GDDR_SYNC33_1 : std_logic ;
  signal CO0_0 : std_logic ;
  signal RESET_FLAG_1_SQMUXA_I : std_logic ;
  signal N_68_I : std_logic ;
  signal UN1_NS_GDDR_SYNC_1_SQMUXA_0_34_1 : std_logic ;
  signal RESET_FLAG_1_SQMUXA_I_1 : std_logic ;
  signal CO2_0_0_0_1 : std_logic ;
  signal N_79_FAST : std_logic ;
  signal G0_MB_1 : std_logic ;
  signal N_68_I_1_1 : std_logic ;
  signal STOP_3 : std_logic ;
  signal READY_4 : std_logic ;
  signal DDR_RESET_D_QN : std_logic ;
  signal RESET_FLAG_QN : std_logic ;
  signal READY_I : std_logic ;
begin
RESET_FLAG_RNO: INV port map (
    A => READY_4,
    Z => READY_I);
\CS_GDDR_SYNC_RNO[0]\: PFUMX port map (
    ALUT => CS_GDDR_SYNC_RNO_0(0),
    BLUT => CS_GDDR_SYNC_RNO_1(0),
    C0 => RESET_FLAG,
    Z => N_68_I);
CS_GDDR_SYNC_RNO_0(0) <= (not READY_4 and N_90 and STOP_3) or 
	(not READY_4 and CS_GDDR_SYNC(1) and STOP_3);
CS_GDDR_SYNC_RNO_1(0) <= (not READY_4 and STOP_3) or 
	(not READY_4 and STOP_ASSERT(1) and N_68_I_1_1);
\STOP_ASSERT[0]_REG_Z85\: FD1S3DX port map (
    D => STOP_ASSERT_4(0),
    CK => sync_clk,
    CD => rst,
    Q => STOP_ASSERT(0));
\STOP_ASSERT[1]_REG_Z87\: FD1S3DX port map (
    D => STOP_ASSERT_4(1),
    CK => sync_clk,
    CD => rst,
    Q => STOP_ASSERT(1));
\STOP_ASSERT[2]_REG_Z89\: FD1S3DX port map (
    D => STOP_ASSERT_4(2),
    CK => sync_clk,
    CD => rst,
    Q => STOP_ASSERT(2));
RESET_FLAG_REG_Z91: FD1P3DX port map (
    D => READY_I,
    SP => RESET_FLAG_1_SQMUXA_I,
    CK => sync_clk,
    CD => rst,
    Q => RESET_FLAG);
DDR_RESET_D_REG_Z93: FD1S3BX port map (
    D => '0',
    CK => sync_clk,
    PD => rst,
    Q => DDR_RESET_D);
\CTRL_CNT[0]_REG_Z95\: FD1S3DX port map (
    D => CTRL_CNT_3(0),
    CK => sync_clk,
    CD => rst,
    Q => CTRL_CNT(0));
\CTRL_CNT[1]_REG_Z97\: FD1S3DX port map (
    D => CTRL_CNT_3(1),
    CK => sync_clk,
    CD => rst,
    Q => CTRL_CNT(1));
\CTRL_CNT[2]_REG_Z99\: FD1S3DX port map (
    D => CTRL_CNT_3(2),
    CK => sync_clk,
    CD => rst,
    Q => CTRL_CNT(2));
\CTRL_CNT[3]_REG_Z101\: FD1S3DX port map (
    D => CTRL_CNT_3(3),
    CK => sync_clk,
    CD => rst,
    Q => CTRL_CNT(3));
\CS_GDDR_SYNC[0]_REG_Z103\: FD1P3DX port map (
    D => N_68_I,
    SP => UN1_NS_GDDR_SYNC36_1,
    CK => sync_clk,
    CD => rst,
    Q => STOP_3);
\CS_GDDR_SYNC[1]_REG_Z105\: FD1P3DX port map (
    D => N_79,
    SP => UN1_NS_GDDR_SYNC36_1,
    CK => sync_clk,
    CD => rst,
    Q => CS_GDDR_SYNC(1));
\CS_GDDR_SYNC_FAST[1]_REG_Z107\: FD1P3DX port map (
    D => N_79_FAST,
    SP => UN1_NS_GDDR_SYNC36_1,
    CK => sync_clk,
    CD => rst,
    Q => CS_GDDR_SYNC_FAST(1));
\CS_GDDR_SYNC[2]_REG_Z109\: FD1P3DX port map (
    D => N_93,
    SP => UN1_NS_GDDR_SYNC36_1,
    CK => sync_clk,
    CD => rst,
    Q => READY_4);
CTRL_CNT_3(2) <= (CO0 and CTRL_CNT(1) and not CTRL_CNT(2) and not UN1_NS_GDDR_SYNC16(0)) or 
	(not CTRL_CNT(1) and CTRL_CNT(2) and not UN1_NS_GDDR_SYNC16(0)) or 
	(not CO0 and CTRL_CNT(2) and not UN1_NS_GDDR_SYNC16(0));
N_79 <= (not N_90 and STOP_3 and not CS_GDDR_SYNC(1) and not RESET_FLAG) or 
	(N_90 and CS_GDDR_SYNC(1));
STOP_ASSERT_4(2) <= (CO0_0 and STOP_ASSERT(1) and not STOP_ASSERT(2)) or 
	(not STOP_ASSERT(1) and STOP_ASSERT(2)) or 
	(not CO0_0 and STOP_ASSERT(2));
STOP_ASSERT_4(1) <= (CO0_0 and not STOP_ASSERT(1)) or 
	(not CO0_0 and STOP_ASSERT(1));
STOP_ASSERT_4(0) <= (not RESET_FLAG and start and not STOP_ASSERT(0) and not STOP_ASSERT(2)) or 
	(not start and STOP_ASSERT(0)) or 
	(RESET_FLAG and STOP_ASSERT(0)) or 
	(STOP_ASSERT(0) and STOP_ASSERT(2));
UN1_NS_GDDR_SYNC36_1 <= (STOP_3 and not READY_4) or 
	(not STOP_3 and not CS_GDDR_SYNC(1));
CO0_0 <= not RESET_FLAG and start and STOP_ASSERT(0) and not STOP_ASSERT(2);
ddr_reset <= (CS_GDDR_SYNC(1)) or 
	(DDR_RESET_D);
CO0 <= CTRL_CNT(0) and not CTRL_CNT(3);
UN1_NS_GDDR_SYNC_1_SQMUXA_0_34_1 <= not STOP_3 and CTRL_CNT(1) and CTRL_CNT(2) and RESET_FLAG;
N_93 <= (READY_4 and start) or 
	(CO0 and start and UN1_NS_GDDR_SYNC_1_SQMUXA_0_34_1);
RESET_FLAG_1_SQMUXA_I_1 <= (READY_4 and not start) or 
	(not CS_GDDR_SYNC(1) and not READY_4) or 
	(not STOP_3 and not READY_4);
RESET_FLAG_1_SQMUXA_I <= (not N_90 and not READY_4 and not RESET_FLAG_1_SQMUXA_I_1) or 
	(READY_4 and NS_GDDR_SYNC33_1 and RESET_FLAG_1_SQMUXA_I_1);
UN1_NS_GDDR_SYNC16(0) <= (not READY_4 and NS_GDDR_SYNC33_1 and not RESET_FLAG) or 
	(not N_90 and not NS_GDDR_SYNC33_1) or 
	(not N_90 and READY_4);
CO2_0_0_0_1 <= CTRL_CNT(0) and CTRL_CNT(1) and CTRL_CNT(2) and not CTRL_CNT(3);
N_90 <= (not CTRL_CNT(1)) or 
	(not CTRL_CNT(0)) or 
	(CTRL_CNT(2)) or 
	(CTRL_CNT(3));
NS_GDDR_SYNC33_1 <= not STOP_3 and not CS_GDDR_SYNC_FAST(1);
N_79_FAST <= (not N_90 and STOP_3 and not CS_GDDR_SYNC_FAST(1) and not RESET_FLAG) or 
	(N_90 and CS_GDDR_SYNC_FAST(1));
CTRL_CNT_3_MB_1(1) <= (not READY_4 and NS_GDDR_SYNC33_1 and not RESET_FLAG) or 
	(not N_90 and not NS_GDDR_SYNC33_1) or 
	(not N_90 and READY_4);
CTRL_CNT_3(1) <= (CO0 and not CTRL_CNT(1) and not CTRL_CNT_3_MB_1(1)) or 
	(not CO0 and CTRL_CNT(1) and not CTRL_CNT_3_MB_1(1));
G0_MB_1 <= (not READY_4 and NS_GDDR_SYNC33_1 and not RESET_FLAG) or 
	(not N_90 and not NS_GDDR_SYNC33_1) or 
	(not N_90 and READY_4);
CTRL_CNT_3(3) <= (CO2_0_0_0_1 and not CTRL_CNT(3) and not G0_MB_1) or 
	(not CO2_0_0_0_1 and CTRL_CNT(3) and not G0_MB_1);
CTRL_CNT_3_MB_1(0) <= (not READY_4 and NS_GDDR_SYNC33_1 and not RESET_FLAG) or 
	(not N_90 and not NS_GDDR_SYNC33_1) or 
	(not N_90 and READY_4);
CTRL_CNT_3(0) <= (not CTRL_CNT(0) and not CTRL_CNT(3) and not CTRL_CNT_3_MB_1(0)) or 
	(CTRL_CNT(0) and CTRL_CNT(3) and not CTRL_CNT_3_MB_1(0));
N_68_I_1_1 <= start and STOP_ASSERT(0) and not STOP_ASSERT(2);
stop <= STOP_3;
ready <= READY_4;
end beh;


library IEEE;
use IEEE.std_logic_1164.all;
library ECP5U;
use ECP5U.components.all;

entity adc_driver is
    port (
        alignwd: in  std_logic; 
        clkin: in  std_logic; 
        ready: out  std_logic; 
        sclk: out  std_logic; 
        start: in  std_logic; 
        sync_clk: in  std_logic; 
        sync_reset: in  std_logic; 
        datain: in  std_logic_vector(11 downto 0); 
        q: out  std_logic_vector(47 downto 0));
end adc_driver;

architecture Structure of adc_driver is

    -- internal signal declarations
    signal ecsout: std_logic;
    signal scuba_vlo: std_logic;
    signal stop: std_logic;
    signal eclki: std_logic;
    signal buf_clkin: std_logic;
    signal qa11: std_logic;
    signal qb11: std_logic;
    signal qc11: std_logic;
    signal qd11: std_logic;
    signal qa10: std_logic;
    signal qb10: std_logic;
    signal qc10: std_logic;
    signal qd10: std_logic;
    signal qa9: std_logic;
    signal qb9: std_logic;
    signal qc9: std_logic;
    signal qd9: std_logic;
    signal qa8: std_logic;
    signal qb8: std_logic;
    signal qc8: std_logic;
    signal qd8: std_logic;
    signal qa7: std_logic;
    signal qb7: std_logic;
    signal qc7: std_logic;
    signal qd7: std_logic;
    signal qa6: std_logic;
    signal qb6: std_logic;
    signal qc6: std_logic;
    signal qd6: std_logic;
    signal qa5: std_logic;
    signal qb5: std_logic;
    signal qc5: std_logic;
    signal qd5: std_logic;
    signal qa4: std_logic;
    signal qb4: std_logic;
    signal qc4: std_logic;
    signal qd4: std_logic;
    signal qa3: std_logic;
    signal qb3: std_logic;
    signal qc3: std_logic;
    signal qd3: std_logic;
    signal qa2: std_logic;
    signal qb2: std_logic;
    signal qc2: std_logic;
    signal qd2: std_logic;
    signal qa1: std_logic;
    signal qb1: std_logic;
    signal qc1: std_logic;
    signal qd1: std_logic;
    signal qa0: std_logic;
    signal qb0: std_logic;
    signal qc0: std_logic;
    signal qd0: std_logic;
    signal reset: std_logic;
    signal eclko: std_logic;
    signal sclk_t: std_logic;
    signal dataini_t11: std_logic;
    signal dataini_t10: std_logic;
    signal dataini_t9: std_logic;
    signal dataini_t8: std_logic;
    signal dataini_t7: std_logic;
    signal dataini_t6: std_logic;
    signal dataini_t5: std_logic;
    signal dataini_t4: std_logic;
    signal dataini_t3: std_logic;
    signal dataini_t2: std_logic;
    signal dataini_t1: std_logic;
    signal dataini_t0: std_logic;
    signal buf_dataini11: std_logic;
    signal buf_dataini10: std_logic;
    signal buf_dataini9: std_logic;
    signal buf_dataini8: std_logic;
    signal buf_dataini7: std_logic;
    signal buf_dataini6: std_logic;
    signal buf_dataini5: std_logic;
    signal buf_dataini4: std_logic;
    signal buf_dataini3: std_logic;
    signal buf_dataini2: std_logic;
    signal buf_dataini1: std_logic;
    signal buf_dataini0: std_logic;

    component adc_drivergddr_sync
        port (rst: in  std_logic; sync_clk: in  std_logic; 
            start: in  std_logic; stop: out  std_logic; 
            ddr_reset: out  std_logic; ready: out  std_logic);
    end component;
    attribute IO_TYPE : string; 
    attribute IO_TYPE of Inst5_IB : label is "LVDS";
    attribute IO_TYPE of Inst1_IB11 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB10 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB9 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB8 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB7 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB6 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB5 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB4 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB3 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB2 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB1 : label is "LVDS";
    attribute IO_TYPE of Inst1_IB0 : label is "LVDS";
    attribute syn_keep : boolean;
    attribute NGD_DRC_MASK : integer;
    attribute NGD_DRC_MASK of Structure : architecture is 1;

begin
    -- component instantiation statements
    Inst5_IB: IB
        port map (I=>clkin, O=>buf_clkin);

    Inst4_CLKDIVF: CLKDIVF
        generic map (DIV=> "2.0")
        port map (CLKI=>eclko, RST=>reset, ALIGNWD=>alignwd, 
            CDIVX=>sclk_t);

    Inst3_ECLKSYNCB: ECLKSYNCB
        port map (ECLKI=>ecsout, STOP=>stop, ECLKO=>eclko);

    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    Inst_ECLKBRIDGECS: ECLKBRIDGECS
        port map (CLK0=>eclki, CLK1=>scuba_vlo, SEL=>scuba_vlo, 
            ECSOUT=>ecsout);

    Inst_gddr_sync: adc_drivergddr_sync
        port map (rst => sync_reset, sync_clk => sync_clk, start => start, 
            stop => stop, ddr_reset => reset, ready => ready);

    Inst2_IDDRX2F11: IDDRX2F
        port map (D=>dataini_t11, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd11, Q2=>qc11, Q1=>qb11, Q0=>qa11);

    Inst2_IDDRX2F10: IDDRX2F
        port map (D=>dataini_t10, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd10, Q2=>qc10, Q1=>qb10, Q0=>qa10);

    Inst2_IDDRX2F9: IDDRX2F
        port map (D=>dataini_t9, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd9, Q2=>qc9, Q1=>qb9, Q0=>qa9);

    Inst2_IDDRX2F8: IDDRX2F
        port map (D=>dataini_t8, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd8, Q2=>qc8, Q1=>qb8, Q0=>qa8);

    Inst2_IDDRX2F7: IDDRX2F
        port map (D=>dataini_t7, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd7, Q2=>qc7, Q1=>qb7, Q0=>qa7);

    Inst2_IDDRX2F6: IDDRX2F
        port map (D=>dataini_t6, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd6, Q2=>qc6, Q1=>qb6, Q0=>qa6);

    Inst2_IDDRX2F5: IDDRX2F
        port map (D=>dataini_t5, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd5, Q2=>qc5, Q1=>qb5, Q0=>qa5);

    Inst2_IDDRX2F4: IDDRX2F
        port map (D=>dataini_t4, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd4, Q2=>qc4, Q1=>qb4, Q0=>qa4);

    Inst2_IDDRX2F3: IDDRX2F
        port map (D=>dataini_t3, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd3, Q2=>qc3, Q1=>qb3, Q0=>qa3);

    Inst2_IDDRX2F2: IDDRX2F
        port map (D=>dataini_t2, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd2, Q2=>qc2, Q1=>qb2, Q0=>qa2);

    Inst2_IDDRX2F1: IDDRX2F
        port map (D=>dataini_t1, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd1, Q2=>qc1, Q1=>qb1, Q0=>qa1);

    Inst2_IDDRX2F0: IDDRX2F
        port map (D=>dataini_t0, SCLK=>sclk_t, ECLK=>eclko, RST=>reset, 
            ALIGNWD=>alignwd, Q3=>qd0, Q2=>qc0, Q1=>qb0, Q0=>qa0);

    udel_dataini11: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini11, Z=>dataini_t11);

    udel_dataini10: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini10, Z=>dataini_t10);

    udel_dataini9: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini9, Z=>dataini_t9);

    udel_dataini8: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini8, Z=>dataini_t8);

    udel_dataini7: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini7, Z=>dataini_t7);

    udel_dataini6: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini6, Z=>dataini_t6);

    udel_dataini5: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini5, Z=>dataini_t5);

    udel_dataini4: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini4, Z=>dataini_t4);

    udel_dataini3: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini3, Z=>dataini_t3);

    udel_dataini2: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini2, Z=>dataini_t2);

    udel_dataini1: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini1, Z=>dataini_t1);

    udel_dataini0: DELAYG
        generic map (DEL_MODE=> "ECLKBRIDGE_CENTERED")
        port map (A=>buf_dataini0, Z=>dataini_t0);

    Inst1_IB11: IB
        port map (I=>datain(11), O=>buf_dataini11);

    Inst1_IB10: IB
        port map (I=>datain(10), O=>buf_dataini10);

    Inst1_IB9: IB
        port map (I=>datain(9), O=>buf_dataini9);

    Inst1_IB8: IB
        port map (I=>datain(8), O=>buf_dataini8);

    Inst1_IB7: IB
        port map (I=>datain(7), O=>buf_dataini7);

    Inst1_IB6: IB
        port map (I=>datain(6), O=>buf_dataini6);

    Inst1_IB5: IB
        port map (I=>datain(5), O=>buf_dataini5);

    Inst1_IB4: IB
        port map (I=>datain(4), O=>buf_dataini4);

    Inst1_IB3: IB
        port map (I=>datain(3), O=>buf_dataini3);

    Inst1_IB2: IB
        port map (I=>datain(2), O=>buf_dataini2);

    Inst1_IB1: IB
        port map (I=>datain(1), O=>buf_dataini1);

    Inst1_IB0: IB
        port map (I=>datain(0), O=>buf_dataini0);

    sclk <= sclk_t;
    q(47) <= qd11;
    q(46) <= qd10;
    q(45) <= qd9;
    q(44) <= qd8;
    q(43) <= qd7;
    q(42) <= qd6;
    q(41) <= qd5;
    q(40) <= qd4;
    q(39) <= qd3;
    q(38) <= qd2;
    q(37) <= qd1;
    q(36) <= qd0;
    q(35) <= qc11;
    q(34) <= qc10;
    q(33) <= qc9;
    q(32) <= qc8;
    q(31) <= qc7;
    q(30) <= qc6;
    q(29) <= qc5;
    q(28) <= qc4;
    q(27) <= qc3;
    q(26) <= qc2;
    q(25) <= qc1;
    q(24) <= qc0;
    q(23) <= qb11;
    q(22) <= qb10;
    q(21) <= qb9;
    q(20) <= qb8;
    q(19) <= qb7;
    q(18) <= qb6;
    q(17) <= qb5;
    q(16) <= qb4;
    q(15) <= qb3;
    q(14) <= qb2;
    q(13) <= qb1;
    q(12) <= qb0;
    q(11) <= qa11;
    q(10) <= qa10;
    q(9) <= qa9;
    q(8) <= qa8;
    q(7) <= qa7;
    q(6) <= qa6;
    q(5) <= qa5;
    q(4) <= qa4;
    q(3) <= qa3;
    q(2) <= qa2;
    q(1) <= qa1;
    q(0) <= qa0;
    eclki <= buf_clkin;
end Structure;
