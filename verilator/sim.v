`timescale 1ps/1ps
// top end ff for verilator

module emu(

	input clk_sys /*verilator public_flat*/,
	input RESET /*verilator public_flat*/,
	input [11:0]  joystick_0/*verilator public_flat*/,
	input [11:0]  joystick_1/*verilator public_flat*/,

	output [7:0] VGA_R/*verilator public_flat*/,
	output [7:0] VGA_G/*verilator public_flat*/,
	output [7:0] VGA_B/*verilator public_flat*/,
	
	output VGA_HS,
	output VGA_VS,
	output VGA_HB,
	output VGA_VB,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,

	input        ioctl_download,
	input        ioctl_upload,
	input        ioctl_wr,
	input [23:0] ioctl_addr,
	input [7:0]  ioctl_dout,
	output [7:0]  ioctl_din,
	input [7:0]  ioctl_index,
	output  reg  ioctl_wait=1'b0,

	output [24:0] sdram_addr/*verilator public_flat*/,
	output        sdram_rd/*verilator public_flat*/,
	output        sdram_wr/*verilator public_flat*/,
	input         sdram_ack/*verilator public_flat*/,
	input  [7:0]  sdram_dout/*verilator public_flat*/,
	output  [7:0]  sdram_din/*verilator public_flat*/

);

	wire ce_pix /*verilator public_flat*/;
	reg pause_cpu /*verilator public_flat*/;

	///////////////////   CONTROLS   ////////////////////
	wire [11:0] joy = joystick_0 | joystick_1;
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
	wire start_p1 = joystick_0[7];
	wire start_p2 = joy[8];

	wire btn_coin = joy[9];
	wire btn_pause = joy[10];
	wire btn_boom = 1'b0;

	wire btn_dual_game_toggle = joy[11];

	// Game metadata
	`include "../rtl/games.v"
	reg [4:0] game_mode;

	reg [7:0] IN_P1;
	reg [7:0] IN_P2;
	reg [7:0] IN_P3;
	reg [7:0] IN_P4;
	reg	landscape;

	always @(posedge clk_sys) 
	begin
		// Set game mode
		if(ioctl_wr && ioctl_index == 8'd1) game_mode <= ioctl_dout[4:0];

		// Set defaults
		landscape <= 1'b0;
		simultaneous2player <= 1'b0;

		// Game specific inputs
		case (game_mode)
			GAME_ALPHAFIGHTER:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, DIP_ALPHAFIGHTER_HEADON_LIVES_3, DIP_ALPHAFIGHTER_LIVES_6[0], ~p2_fire1, ~p2_up };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_ALPHAFIGHTER_LIVES_6[1], 1'b1, ~p2_right };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_ALPHAFIGHTER_BONUSLIFE_1500, 1'b1, ~p2_down };
				IN_P4 <= { 2'b11, ~start_p2, 2'b11, DIP_ALPHAFIGHTER_BONUSLIFEFORFINALUFO_ON, 1'b1, ~p2_left };
			end
			GAME_BORDERLINE:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, DIP_BORDERLINE_CABINET_OFF, DIP_BORDERLINE_LIVES_INFINITE[0], ~p2_fire1, ~p2_up };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_BORDERLINE_LIVES_INFINITE[1], ~p1_fire1, ~p2_right };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_BORDERLINE_LIVES_INFINITE[2], 1'b1, ~p2_down };
				IN_P4 <= { 2'b11, ~start_p2, 2'b11, DIP_BORDERLINE_BONUSLIFE_15000, 1'b1, ~p2_left };
			end
			GAME_CARHUNT_DUAL:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, DIP_CARHUNT_DUAL_GAME1_LIVES_3[0], 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_CARHUNT_DUAL_GAME1_LIVES_3[1], 2'b11 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_CARHUNT_DUAL_GAME2_LIVES_4[0], 2'b11 };
				IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, DIP_CARHUNT_DUAL_GAME2_LIVES_4[1], 2'b11 };
			end
			GAME_CARNIVAL:
			begin
				IN_P1 <= { 3'b111, DIP_CARNIVAL_DEMOSOUNDS_ON, 4'b1111 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 4'b1011 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
				IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
			end
			GAME_DIGGER:
			begin
				IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire2, ~p1_fire1, ~start_p2, ~start_p1 };
				IN_P3 <= { 6'b111111, DIP_DIGGER_LIVES_3 };
			end
			GAME_FROGS:
			begin
				IN_P1 <= { ~p1_fire1, DIP_FROGS_COINAGE_1C1C, DIP_FROGS_GAMETIME_90, DIP_FROGS_FREEGAME_YES, DIP_FROGS_DEMOSOUNDS_ON, ~p1_left, ~p1_up, ~p1_right };
			end
			GAME_HEADON:
			begin
				IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire1, DIP_HEADON_DEMOSOUNDS_ON, DIP_HEADON_LIVES_6 };
				landscape <= 1'b1;
			end
			GAME_HEADON2:
			begin
				IN_P1 <= { ~p1_up, ~p1_left, ~p1_down, ~p1_right, ~p1_fire1, 1'b1, ~start_p2, ~start_p1 };
				IN_P3 <= { 3'b111, DIP_HEADON2_LIVES_4, 3'b111 };
				IN_P4 <= { 6'b111111, DIP_HEADON2_DEMOSOUNDS_ON, 1'b1 };
				landscape <= 1'b1;
			end
			GAME_HEIANKYO:
			begin
			IN_P1 <= { 2'b11, ~p1_fire1, ~p1_up, DIP_HEIANKYO_2PLAYERMODE_SIMULTANEOUS, 1'b1, ~p2_fire2, ~p2_up };
			IN_P2 <= { 2'b11, ~p1_fire2, ~p1_right, 2'b01, ~p2_fire2, ~p2_right };
			IN_P3 <= { 3'b110, ~p1_down, 3'b110, ~p1_down };
			IN_P4 <= { 2'b11, ~start_p1, ~p1_left, 1'b1, DIP_HEIANKYO_LIVES_5, ~start_p2, ~p2_left };
			simultaneous2player <= 1'b1;
			end
			GAME_INVINCO:
			begin
				IN_P1 <= { 1'b1, ~p1_left, 1'b1, ~p1_right, ~p1_fire1, 1'b1, ~start_p2, ~start_p1 };
				IN_P3 <= { 6'b11, DIP_INVINCO_LIVES_3 };
			end
			GAME_INVINCO_DEEPSCAN:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, DIP_INVINCO_DEEPSCAN_GAME1_LIVES_3[0], 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_INVINCO_DEEPSCAN_GAME1_LIVES_3[1], 2'b11 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_INVINCO_DEEPSCAN_GAME2_LIVES_4[0], 2'b11 };
				IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, DIP_INVINCO_DEEPSCAN_GAME2_LIVES_4[1], 2'b11 };
			end
			GAME_INVINCO_HEADON2:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, DIP_INVINCO_HEADON2_GAME1_LIVES_2[0], 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_INVINCO_HEADON2_GAME1_LIVES_2[1], 2'b11 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_INVINCO_HEADON2_GAME2_LIVES_5[0], 2'b11 };
				IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, DIP_INVINCO_HEADON2_GAME2_LIVES_5[1], 2'b11 };
			end
			GAME_NSUB:
			begin
				IN_P1 <= ~{ p1_up, p1_left, p1_down, p1_right, p1_fire2, p1_fire1, start_p2, start_p1 };
			end
			GAME_PULSAR:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, DIP_PULSAR_LIVES_5[0], 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_PULSAR_LIVES_5[1], 2'b11 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
				IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
			end
			GAME_SAFARI:
			begin
				IN_P1 <= { ~p1_fire1, 1'b1, ~p1_fire3, ~p1_fire2, ~p1_left, ~p1_right, ~p1_down, ~p1_up };
				landscape <= 1'b1;
			end
			GAME_SAMURAI:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, DIP_SAMURAI_INFINITELIVES_OFF, DIP_SAMURAI_LIVES_3, 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 4'b1111 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 4'b1111 };
				IN_P4 <= { 2'b11, ~start_p2, 5'b11111 };
			end
			GAME_SPACEATTACK:
			begin
				IN_P1 <= { ~p1_left, ~p2_left, ~p2_right, ~p2_fire1, ~start_p2, ~start_p1, ~p1_fire1, ~p1_right };
				IN_P3 <= { DIP_SPACEATTACK_CREDITSDISPLAY_ON, 2'b11, DIP_SPACEATTACK_BONUSLIFE_15000, DIP_SPACEATTACK_LIVES_5, DIP_SPACEATTACK_BONUSLIFEFORFINALUFO_ON };
			end
			GAME_SPACEATTACK_HEADON:
			begin
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, DIP_SPACEATTACK_HEADON_GAME2_LIVES_4, DIP_SPACEATTACK_HEADON_GAME1_LIVES_5[0], ~p2_fire1, ~p2_up };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_SPACEATTACK_HEADON_GAME1_LIVES_5[1], 1'b1, ~p2_right };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_SPACEATTACK_HEADON_BONUSLIFE_15000, 1'b1, ~p2_down };
				IN_P4 <= { 2'b11, ~start_p2, 2'b11, DIP_SPACEATTACK_HEADON_BONUSLIFEFORFINALUFO_ON, 1'b1, ~p2_left };
			end
			GAME_SPACETREK:
			begin
				IN_P1 <= { 2'b11, ~p1_left, ~p1_right, 1'b1, DIP_SPACETREK_LIVES_4, 2'b11 };
				IN_P2 <= { 2'b11, ~p1_up, ~p1_down, 4'b1111 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_SPACETREK_BONUSLIFE_ON, 2'b11 };
				IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 4'b1111 };
			end
			GAME_STARRAKER:
			begin
				IN_P1 <= { 2'b11, ~p1_left, ~p1_right, DIP_STARRAKER_CABINET_ON, 1'b1, ~p1_fire1, ~p1_up };
				IN_P2 <= { 2'b11, ~p1_up, ~p1_down, 2'b11, ~p1_fire1, ~p1_right };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 3'b111, ~p1_down };
				IN_P4 <= { 2'b11, ~start_p2, 2'b11, DIP_STARRAKER_BONUSLIFE_15000, 1'b1, ~p1_left };
			end
			GAME_SUBHUNT:
			begin
				// IN_P1 <= ~{ 2'b0, p1_left, p1_right, 2'b0, fire1, p1_up };
				// IN_P2 <= ~{ 2'b0, p1_up, p1_down, 2'b0, fire1, p1_right };
				// IN_P3 <= ~{ 2'b0, fire1, start_p1, 3'b0, p1_down };
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
				IN_P1 <= { 2'b11, ~p1_up, ~p1_down, 1'b1, DIP_WANTED_LIVES_3[0], 2'b11 };
				IN_P2 <= { 2'b11, ~p1_right, ~p1_left, 1'b1, DIP_WANTED_LIVES_3[1], 2'b11 };
				IN_P3 <= { 2'b11, ~p1_fire1, ~start_p1, 1'b1, DIP_WANTED_CABINET_OFF, 2'b11 };
				IN_P4 <= { 2'b11, ~start_p2, ~p1_fire2, 1'b1, DIP_WANTED_BONUSLIFE_20000, 2'b11 };
			end
		endcase
	end

	// Convert video output to 8bpp RGB
	wire [23:0] rgb;
	assign VGA_R = rgb[7:0];
	assign VGA_G = rgb[15:8];
	assign VGA_B = rgb[23:16];

	reg rom_downloaded = 0;
	wire rom_download = ioctl_download && (ioctl_index == 8'd0 || ioctl_index == 8'd2);
	reg [7:0] rom_download_timer;
	wire reset/*verilator public_flat*/;
	assign reset = (RESET | rom_download_timer > 0 | !rom_downloaded); 
	always @(posedge clk_sys) 
	begin
		if(rom_download)
		begin
			rom_download_timer <= 8'hFF;
			rom_downloaded <= 1'b1; // Latch downloaded rom state to release reset
		end
		else
		begin
			if(rom_download_timer > 8'h0) rom_download_timer <= rom_download_timer - 8'd1;
		end
	end

	wire [24:0] sdram_addr_out;
	assign sdram_addr = sdram_wr ? {1'b0, ioctl_addr} : sdram_addr_out;
	assign sdram_wr = ioctl_download && ioctl_wr && ioctl_index == 8'd2;
	assign sdram_din = ioctl_dout;

	system system (
		.clk(clk_sys),
		.clk_sfx(clk_sys),
		.reset(reset),
		.pause(pause_cpu),
		.game_mode(game_mode),
		.ce_pix(ce_pix),
		.rgb(rgb),
		.in_p1(IN_P1),
		.in_p2(IN_P2),
		.in_p3(IN_P3),
		.in_p4(IN_P4),
		.coin(btn_coin),
		.dual_game_toggle(btn_dual_game_toggle),
		.hsync(VGA_HS),
		.vsync(VGA_VS),
		.hblank(VGA_HB),
		.vblank(VGA_VB),
		.dn_addr(ioctl_addr[23:0]),
		.dn_index(ioctl_index),
		.dn_data(ioctl_dout),
		.dn_download(ioctl_download),
		.dn_wr(ioctl_wr),
		.sdram_addr(sdram_addr_out),
		.sdram_dout(sdram_dout),
		.sdram_rd(sdram_rd),
		.sdram_ack(sdram_ack),
		.audio_l(AUDIO_L),
		.audio_r(AUDIO_R),
		.hs_address(hs_address),
		.hs_data_in(hs_data_in),
		.hs_data_out(hs_data_out),
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

wire OSD_STATUS;
wire ioctl_upload_req;

hiscore_sim #(
	.HS_ADDRESSWIDTH(12),
	.CFG_ADDRESSWIDTH(3),
	.CFG_LENGTHWIDTH(2),
	.HS_CONFIGINDEX(5)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(1'b0),
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
