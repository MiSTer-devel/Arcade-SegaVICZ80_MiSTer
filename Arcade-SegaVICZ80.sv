/*============================================================================
	FPGA implementation of Z80-based 'VIC' era arcade hardware by Gremlin Industries/Sega Enterprises

	Author: Jim Gregory - https://github.com/JimmyStones/
	Version: 1.0
	Date: 2024-01-06

	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
===========================================================================*/

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign FB_FORCE_BLANK = 0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? ((status[2] | landscape) ? 8'd8 : 8'd7) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] | landscape) ? 8'd7 : 8'd8) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.VICZ80;;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"OGJ,Analog Video H-Pos,0,-1,-2,-3,-4,-5,-6,-7,8,7,6,5,4,3,2,1;",
	"OKN,Analog Video V-Pos,0,-1,-2,-3,-4,-5,-6,-7,8,7,6,5,4,3,2,1;",
	"-;",
	"H2OP,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OQ,Pause when OSD is open,On,Off;",
	"P1OR,Dim video after 10s,On,Off;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Start 1P,Start 2P,Coin,Pause;",
	"Jn,A,B,Start,C,R,L;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire clk_vid;
wire clk_mem;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_vid),
	.outclk_2(clk_mem),
	.locked(pll_locked)
);

////////////////////   HPS   /////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;

wire [15:0] joystick_0, joystick_1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({landscape,direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);


///////////////////   CONTROLS   ////////////////////
wire [11:0] joy = joystick_0[11:0] | joystick_1[11:0];
reg simultaneous2player;
wire p1_right = simultaneous2player ? joystick_0[0] : joy[0];
wire p2_right = simultaneous2player ? joystick_1[0] : joy[0];
wire p1_left = simultaneous2player ? joystick_0[1] : joy[1];
wire p2_left = simultaneous2player ? joystick_1[1] : joy[1];
wire p1_down = simultaneous2player ? joystick_0[2] : joy[2];
wire p2_down = simultaneous2player ? joystick_1[2] : joy[2];
wire p1_up = simultaneous2player ? joystick_0[3] : joy[3];
wire p2_up = simultaneous2player ? joystick_1[3] : joy[3];
wire p1_fire1 = simultaneous2player ? joystick_0[4] : joy[4];
wire p2_fire1 = simultaneous2player ? joystick_1[4] : joy[4];
wire p1_fire2 = simultaneous2player ? joystick_0[5] : joy[5];
wire p2_fire2 = simultaneous2player ? joystick_1[5] : joy[5];
wire p1_fire3 = simultaneous2player ? joystick_0[6] : joy[6];
wire p2_fire3 = simultaneous2player ? joystick_1[6] : joy[6];
wire start_p1 = joystick_0[7];
wire start_p2 = joy[8];

wire btn_coin = joy[9];
wire btn_pause = joy[10];
wire btn_dual_game_toggle = joy[11];

///////////////////   DIPS   ////////////////////
reg [7:0] sw[8];
always @(posedge clk_sys)
begin
	if (ioctl_wr && (ioctl_index==8'd254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;
end

// Game metadata
`include "rtl/games.v"

// Extract per-game DIPs
// - Alpha Fighter / Head On
wire dip_alphafighter_headon_lives = sw[0][0];
wire [1:0] dip_alphafighter_lives = sw[0][2:1];
wire dip_alphafighter_bonuslifeforfinalufo = sw[0][3];
wire dip_alphafighter_bonuslife = sw[0][4];
// - Borderline
wire dip_borderline_cabinet = sw[0][0];
wire dip_borderline_bonuslife = sw[0][1];
wire [2:0] dip_borderline_lives = sw[0][4:2];
// - Car Hunt / Deep Scan (France) & Invinco + Car Hunt (Germany)
wire [1:0] dip_carhunt_dual_game1_lives = sw[0][1:0];
wire [1:0] dip_carhunt_dual_game2_lives = sw[0][3:2];
// - Carnival
wire dip_carnival_demosounds = sw[0][0];
// - Digger
wire [1:0] dip_digger_lives = sw[0][1:0];
// - Frogs
wire dip_frogs_demosounds = sw[0][0];
wire dip_frogs_freegame = sw[0][1];
wire dip_frogs_gametime = sw[0][2];
wire dip_frogs_coinage = sw[0][3];
// - Head On
wire dip_headon_demosounds = sw[0][0];
wire [1:0] dip_headon_lives = sw[0][2:1];
// - Head On 2
wire dip_headon2_demosounds = sw[0][0];
wire [1:0] dip_headon2_lives = sw[0][2:1];
// - Heiankyo Alien
wire dip_heiankyo_2player = sw[0][0];
wire dip_heiankyo_lives = sw[0][1];
// - Invinco
wire [1:0] dip_invinco_lives = sw[0][1:0];
// - Invinco / Deep Scan
wire [1:0] dip_invinco_deepscan_game1_lives = sw[0][1:0];
wire [1:0] dip_invinco_deepscan_game2_lives = sw[0][3:2];
// - Invinco / Head On 2
wire [1:0] dip_invinco_headon2_game1_lives = sw[0][1:0];
wire [1:0] dip_invinco_headon2_game2_lives = sw[0][3:2];
// - N-Sub

// - Pulsar
wire [1:0] dip_pulsar_lives = sw[0][1:0];
// - Safari

// - Samurai
wire dip_samurai_lives = sw[0][0];
// - Space Attack
wire dip_spaceattack_bonuslifeforfinalufo = sw[0][0];
wire [2:0] dip_spaceattack_lives = (sw[0][2:1] == 2'd0) ? DIP_SPACEATTACK_LIVES_3 :
									(sw[0][2:1] == 2'd1) ? DIP_SPACEATTACK_LIVES_4 :
									(sw[0][2:1] == 2'd2) ? DIP_SPACEATTACK_LIVES_5 :
									DIP_SPACEATTACK_LIVES_6;
wire dip_spaceattack_bonuslife = sw[0][3]; 
wire dip_spaceattack_creditsdisplay = sw[0][4];
// - Space Attack + Head On
wire dip_spaceattack_headon_bonuslifeforfinalufo = sw[0][0];
wire [1:0] dip_spaceattack_headon_game1_lives = sw[0][2:1];
wire dip_spaceattack_headon_bonuslife = sw[0][3]; 
wire dip_spaceattack_headon_creditsdisplay = sw[0][4];
wire dip_spaceattack_headon_game2_lives = sw[0][5];
// - Space Trek
wire dip_spacetrek_lives = sw[0][0];
wire dip_spacetrek_bonuslife = sw[0][1];
// - Star Raker
wire dip_starraker_cabinet = sw[0][0];
wire dip_starraker_bonuslife = sw[0][1];
// - Sub Hunt

// - Tranquilizer Gun
// N/A
// - Wanted
wire dip_wanted_cabinet = sw[0][0];
wire dip_wanted_bonuslife = sw[0][1];
wire [1:0] dip_wanted_lives = sw[0][3:2];


///////////////////   CORE INPUTS   ////////////////////
reg [4:0] game_mode /*verilator public_flat*/;
reg	[7:0]	IN_P1;
reg	[7:0]	IN_P2;
reg	[7:0]	IN_P3;
reg	[7:0]	IN_P4;
reg			landscape;

always @(posedge clk_sys) 
begin
	// Set game mode
	if (ioctl_wr && (ioctl_index==8'd1)) game_mode <= ioctl_dout[4:0];

	// Set defaults
	landscape <= 1'b0;
	simultaneous2player <= 1'b0;

	IN_P1 <= 8'hFF;
	IN_P2 <= 8'hFF;
	IN_P3 <= 8'hFF;
	IN_P4 <= 8'hFF;

	// Game specific inputs
	case (game_mode)
		GAME_ALPHAFIGHTER:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, dip_alphafighter_headon_lives, dip_alphafighter_lives[0], ~p2_fire1, ~p2_up };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_alphafighter_lives[1], 1'b1, ~p2_right };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_alphafighter_bonuslife, 1'b1, ~p2_down };
			IN_P4 <= { 2'b11, ~start_p2, 2'b11, dip_alphafighter_bonuslifeforfinalufo, 1'b1, ~p2_left };
		end
		GAME_BORDERLINE:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, dip_borderline_cabinet, dip_borderline_lives[0], ~p1_fire1, ~p1_up };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_borderline_lives[1], ~p1_fire1, ~p1_right };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_borderline_lives[2], 1'b1, ~p1_down };
			IN_P4 <= { 2'b11, ~start_p2, 2'b11, dip_borderline_bonuslife, 1'b1, ~p1_left };
		end
		GAME_CARHUNT_DUAL:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_carhunt_dual_game1_lives[0], 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_carhunt_dual_game1_lives[1], 2'b11 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_carhunt_dual_game2_lives[0], 2'b11 };
			IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, dip_carhunt_dual_game2_lives[1], 2'b11 };
		end
		GAME_CARNIVAL:
		begin
			IN_P1 <= { 3'b111, dip_carnival_demosounds, 4'b1111 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 4'b1011 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
			IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
		end
		GAME_DIGGER:
		begin
			IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire2, ~p1_fire1, ~start_p2, ~start_p1 };
			IN_P3 <= { 6'b111111, dip_digger_lives };
		end
		GAME_FROGS:
		begin
			IN_P1 <= { ~p1_fire1, dip_frogs_coinage, dip_frogs_gametime, dip_frogs_freegame, dip_frogs_demosounds, ~p1_left, ~p1_up, ~p1_right };
			landscape <= 1'b1;
		end
		GAME_HEADON:
		begin
			IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire1, dip_headon_demosounds, dip_headon_lives };
			landscape <= 1'b1;
		end
		GAME_HEADON2:
		begin
			IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire1, 1'b1, ~start_p2, ~start_p1 };
			IN_P3 <= { 3'b111, dip_headon2_lives, 3'b111 };
			IN_P4 <= { 6'b111111, dip_headon2_demosounds, 1'b1 };
			landscape <= 1'b1;
		end
		GAME_HEIANKYO:
		begin
			IN_P1 <= { 2'b11, ~p1_fire1, ~p1_up, dip_heiankyo_2player, 1'b1, ~p2_fire2, ~p2_up };
			IN_P2 <= { 2'b11, ~p1_fire2, ~p1_right, 2'b01, ~p2_fire2, ~p2_right };
			IN_P3 <= { 3'b110, ~p1_down, 3'b110, ~p1_down };
			IN_P4 <= { 2'b11, ~start_p1, ~p1_left, 1'b1, dip_heiankyo_lives, ~start_p2, ~p2_left };
			simultaneous2player <= ~dip_heiankyo_2player;
		end
		GAME_INVINCO:
		begin
			IN_P1 <= { 1'b1, ~p1_left, 1'b1, ~p1_right, ~p1_fire1, 1'b1, ~start_p2, ~start_p1 };
			IN_P3 <= { 6'b11, dip_invinco_lives };
		end
		GAME_INVINCO_DEEPSCAN:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_invinco_deepscan_game1_lives[0], 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_invinco_deepscan_game1_lives[1], 2'b11 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_invinco_deepscan_game2_lives[0], 2'b11 };
			IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, dip_invinco_deepscan_game2_lives[1], 2'b11 };
		end
		GAME_INVINCO_HEADON2:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_invinco_headon2_game1_lives[0], 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_invinco_headon2_game1_lives[1], 2'b11 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_invinco_headon2_game2_lives[0], 2'b11 };
			IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, dip_invinco_headon2_game2_lives[1], 2'b11 };
		end
		GAME_NSUB:
		begin
			IN_P1 <= ~{ p1_up, p1_left, p1_down, p1_right, p1_fire2, p1_fire1, start_p2, start_p1 };
		end
		GAME_PULSAR:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_pulsar_lives[0], 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_pulsar_lives[1], 2'b11 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
			IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
		end
		GAME_SAFARI:
		begin
			IN_P1 <= { ~p1_fire1, 1'b0, ~p1_fire3, ~p1_fire2, ~p1_left, ~p1_right, ~p1_down, ~p1_up };
			landscape <= 1'b1;
		end
		GAME_SAMURAI:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_samurai_lives, 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 4'b1111 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
			IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
		end
		GAME_SPACEATTACK:
		begin
			IN_P1 <= { ~p1_left, ~p2_left, ~p2_right, ~p2_fire1, ~start_p2, ~start_p1, ~p1_fire1, ~p1_right };
			IN_P3 <= { dip_spaceattack_creditsdisplay, 2'b11, dip_spaceattack_bonuslife, dip_spaceattack_lives, dip_spaceattack_bonuslifeforfinalufo };
		end
		GAME_SPACEATTACK_HEADON:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, dip_spaceattack_headon_game2_lives, dip_spaceattack_headon_game1_lives[0], ~p2_fire1, ~p2_up };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_spaceattack_headon_game1_lives[1], 1'b1, ~p2_right };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_spaceattack_headon_bonuslife, 1'b1, ~p2_down };
			IN_P4 <= { 2'b11, ~start_p2, 2'b11, dip_spaceattack_headon_bonuslifeforfinalufo, 1'b1, ~p2_left };
		end
		GAME_SPACETREK:
		begin
			IN_P1 <= { 2'b11, ~p1_left, ~p1_right, 1'b1, dip_spacetrek_lives, 2'b11 };
			IN_P2 <= { 2'b11, ~p1_up, ~p1_down, 4'b1111 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_spacetrek_bonuslife, 2'b11 };
			IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 4'b1111 };
		end
		GAME_STARRAKER:
		begin
			IN_P1 <= { 2'b11, ~p1_left, ~p1_right, dip_starraker_cabinet, 1'b1, ~p1_fire1, ~p1_up };
			IN_P2 <= { 2'b11, ~p1_up, ~p1_down, 2'b11, ~p1_fire1, ~p1_right };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 3'b111, ~p1_down };
			IN_P4 <= { 2'b11, ~start_p2, 2'b11, dip_starraker_bonuslife, 1'b1, ~p1_left };
		end
		GAME_SUBHUNT:
		begin
			// IN_P1 <= ~{ 2'b0, p1_left, p1_right, 2'b0, p1_fire1, p1_up };
			// IN_P2 <= ~{ 2'b0, p1_up, p1_down, 2'b0, p1_fire1, p1_right };
			// IN_P3 <= ~{ 2'b0, p1_fire1, start_p1, 3'b0, p1_down };
			// IN_P4 <= ~{ 2'b0, start_p2, 4'b0, p1_left };
		end
		GAME_TRANQUILIZERGUN:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 2'b11, ~p1_fire1, ~p1_up };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 3'b111, ~p1_right };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 3'b111, ~p1_down };
			IN_P4 <= { 2'b11, ~start_p2, 4'b1111, ~p1_left };
		end
		GAME_WANTED:
		begin
			IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, dip_wanted_lives[0], 2'b11 };
			IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, dip_wanted_lives[1], 2'b11 };
			IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, dip_wanted_cabinet, 2'b11 };
			IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, dip_wanted_bonuslife, 2'b11 };
		end
	endcase
end

///////////////////   VIDEO   ////////////////////
reg ce_pix;
wire hblank, vblank, hs, vs, hs_original, vs_original;
wire [23:0] video_rgb;
wire [23:0] rgb_out;

wire rotate_ccw = 1;
wire no_rotate = status[2] | direct_video | landscape;
wire flip = ~no_rotate;
wire video_rotated;

screen_rotate screen_rotate (.*);

arcade_video #(256,24) arcade_video
(
	.*,
	.clk_video(clk_vid),
	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.fx(status[5:3])
);

// H/V offset
wire [3:0]  voffset = status[23:20];
wire [3:0]  hoffset = status[19:16];
jtframe_resync jtframe_resync
(
	.clk(clk_sys),
	.pxl_cen(ce_pix),
	.hs_in(hs_original),
	.vs_in(vs_original),
	.LVBL(~vblank),
	.LHBL(~hblank),
	.hoffset(hoffset),
	.voffset(voffset),
	.hs_out(hs),
	.vs_out(vs)
);

///////////////////   WAVE AUDIO STORAGE   ///////////////////
wire [7:0]  sdram_dout;
wire [24:0] sdram_addr;
reg         sdram_ack;
reg         sdram_rd;
wire sdram_ready;
reg  [15:0] wav_data_o;
wire sdram_download = ioctl_download && ioctl_wr && ioctl_index == 8'd2;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_mem),

	.addr(sdram_download ? ioctl_addr : sdram_addr[24:0]),
	.we(sdram_download),
	.rd(~sdram_download & sdram_rd),
	.din(ioctl_dout),
	.dout(wav_data_o),
	.ready(sdram_ready)
);

always @(posedge clk_mem)
begin
	reg sdram_ready_last;
	sdram_ready_last <= sdram_ready;
	// Latch upper/lower SDRAM data out when data is ready
	if(sdram_ready && ~sdram_ready_last) 
	begin
		sdram_dout <= !sdram_addr[0] ? wav_data_o[7:0] : wav_data_o[15:8];
		sdram_ack <= ~sdram_ack;
	end
end


///////////////////   PAUSE   ///////////////////
wire		pause_cpu;
pause #(8,8,8,24) pause (
	.*,
	.r(video_rgb[7:0]),
	.g(video_rgb[15:8]),
	.b(video_rgb[23:16]),
	.user_button(btn_pause),
	.pause_request(hs_pause),
	.options(~status[27:26])
);

///////////////////   GAME   ////////////////////
reg rom_downloaded = 1'b0;
wire rom_download = ioctl_download && ioctl_index == 8'b0;
wire reset = (RESET | status[0] | buttons[1] | rom_download | ~rom_downloaded);
assign LED_USER = rom_download;
// Latch release reset if ROM data is received (stops sound circuit from going off if ROMs are not found)
always @(posedge clk_sys) if(rom_download && ioctl_dout > 8'b0) rom_downloaded <= 1'b1; 

system system (
	.clk(clk_sys),
	.clk_sfx(clk_mem),
	.reset(reset),
	.pause(pause_cpu),
	.game_mode(game_mode),
	.ce_pix(ce_pix),
	.rgb(video_rgb),
	.in_p1(IN_P1),
	.in_p2(IN_P2),
	.in_p3(IN_P3),
	.in_p4(IN_P4),
	.coin(btn_coin),
	.dual_game_toggle(btn_dual_game_toggle),
	.hsync(hs_original),
	.vsync(vs_original),
	.hblank(hblank),
	.vblank(vblank),
	.dn_addr(ioctl_addr[15:0]),
	.dn_index(ioctl_index),
	.dn_data(ioctl_dout),
	.dn_download(ioctl_download),
	.dn_wr(ioctl_wr),
	.sdram_addr(sdram_addr),
	.sdram_dout(sdram_dout),
	.sdram_rd(sdram_rd),
	.sdram_ack(sdram_ack),
	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R),
	
	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write_enable(hs_write_enable)
);

// HISCORE SYSTEM
// --------------

wire [11:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_access_read;
wire hs_access_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(12),
	.CFG_ADDRESSWIDTH(3),
	.CFG_LENGTHWIDTH(2),
	.HS_CONFIGINDEX(5)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[25]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);


endmodule