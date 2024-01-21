#include <verilated.h>
#include "Vemu.h"

#include "imgui.h"
#include "implot.h"
#ifndef _MSC_VER
#include <stdio.h>
#include <SDL.h>
#include <SDL_opengl.h>
#else
#define WIN32
#include <dinput.h>
#endif

#include "sim_console.h"
#include "sim_ddram.h"
#include "sim_sdram.h"
#include "sim_bus.h"
#include "sim_video.h"
#include "sim_audio.h"
#include "sim_input.h"
#include "sim_clock.h"

#include "../imgui/imgui_memory_editor.h"
//#include "../imgui/ImGuiFileDialog.h"

#define FMT_HEADER_ONLY
#include <fmt/core.h>

#include <iostream>
#include <sstream>
#include <fstream>
#include <iterator>
#include <string>
#include <iomanip>

using namespace std;

// Simulation control
// ------------------
int initialReset = 48;
bool run_enable = 1;
bool pause_game = 0;
int batchSize = 25000000 / 100;
bool single_step = 0;
bool multi_step = 0;
int multi_step_amount = 1024;

//#define IS_ALPHAFIGHTER
//#define IS_BORDERLINE
//#define IS_CARHUNTDEEPSCAN
//#define IS_CARNIVAL
//#define IS_DIGGER
//#define IS_FROGS
//#define IS_HEADON
//#define IS_HEADONMZ
//#define IS_HEADON2
//#define IS_HEIANKYO
//#define IS_INVINCOCARHUNT
//#define IS_INVINCODEEPSCAN
//#define IS_INVINCOHEADON2
//#define IS_INVINCO
//#define IS_MISSILECIRCUIT
//#define IS_NSUB
#define IS_PULSAR
//#define IS_SAFARI
//#define IS_SAMURAI
//#define IS_SPACEATTACK
//#define IS_SPACEATTACKHEADON
//#define IS_SPACETREK
//#define IS_STARRAKER
//#define IS_SUBHUNT
//#define IS_TRANQUILIZERGUN
//#define IS_WANTED

// Debug GUI 
// ---------
const char* windowTitle = "Verilator Sim: Sega/Gremlin - VIC";
const char* windowTitle_Control = "Simulation control";
const char* windowTitle_DebugLog = "Debug log";
const char* windowTitle_Video = "VGA output";
const char* windowTitle_Audio = "Audio output";
bool showDebugLog = true;
DebugConsole console;
MemoryEditor mem_edit_8;
MemoryEditor mem_edit_16;

// MiSTer framework emulation
// ------------
#define DDRAM_START 0x30000000
#define DDRAM_SIZE 0x10000000
SimDDRAM ddram(console, DDRAM_START, DDRAM_SIZE);
SimSDRAM sdram(console);
SimBus bus(console, &ddram, &sdram);

// Input handling
// --------------
SimInput input_0(12, console);
SimInput input_1(12, console);

const int input_right = 0;
const int input_left = 1;
const int input_down = 2;
const int input_up = 3;
const int input_fire1 = 4;
const int input_fire2 = 5;
const int input_fire3 = 6;
const int input_start1 = 7;
const int input_start2 = 8;
const int input_coin = 9;
const int input_pause = 10;
const int input_dual_game_toggle = 11;

// Verilog module
// --------------
Vemu* top = NULL;
vluint64_t main_time = 0; // Current simulation time.
double sc_time_stamp()
{ // Called by $time in Verilog.
	return main_time;
}

int clk_vid_freq = 15468480 * 2;
int clk_sys_freq = 15468480;
SimClock clk_vid(1);
SimClock clk_sys(1);

void resetSim()
{
	main_time = 0;
	top->RESET = 1;
	clk_vid.Reset();
	clk_sys.Reset();
}

// Game specific setup

#ifdef IS_ALPHAFIGHTER
#define VGA_ROTATE -1
std::string mraFilename = "Alpha Fighter + Head On.mra";
#endif
#ifdef IS_BORDERLINE
#define VGA_ROTATE -1
std::string mraFilename = "Borderline.mra";
std::string tracefilename = "traces/borderline.tr";
#endif
#ifdef IS_CARHUNTDEEPSCAN
#define VGA_ROTATE -1
std::string mraFilename = "Car Hunt + Deep Scan (France).mra";
std::string tracefilename = "traces/carhntds.tr";
#endif
#ifdef IS_CARNIVAL
#define VGA_ROTATE -1
std::string mraFilename = "Carnival.mra";
std::string nvmFilename = "Carnival.nvm";
#endif
#ifdef IS_DIGGER
#define VGA_ROTATE -1  
std::string mraFilename = "Digger.mra";
#endif
#ifdef IS_HEADON
#define VGA_ROTATE 0 
std::string mraFilename = "Head On.mra";
std::string tracefilename = "traces/headon.tr";
#endif
#ifdef IS_HEADONMZ
#define VGA_ROTATE 0
std::string mraFilename = "Head On (bootleg alt maze).mra";
#endif
#ifdef IS_INVINCOCARHUNT
#define VGA_ROTATE -1
std::string mraFilename = "Invinco + Car Hunt (Germany).mra";
#endif
#ifdef IS_INVINCODEEPSCAN
#define VGA_ROTATE -1
std::string mraFilename = "Invinco + Deep Scan.mra";
#endif
#ifdef IS_INVINCOHEADON2
#define VGA_ROTATE -1
std::string mraFilename = "Invinco + Head On 2.mra";
#endif
#ifdef IS_INVINCO
#define VGA_ROTATE -1
std::string mraFilename = "Invinco.mra";
std::string tracefilename = "traces/invinco.tr";
#endif
#ifdef IS_PULSAR
#define VGA_ROTATE -1  
std::string mraFilename = "Pulsar.mra";
std::string tracefilename = "traces/pulsar.tr";
std::string nvmFilename = "Pulsar.nvm";
#endif
#ifdef IS_HEADON2
#define VGA_ROTATE 0
std::string mraFilename = "Head On 2.mra";
//std::string tracefilename = "traces/pulsar.tr";
#endif
#ifdef IS_FROGS
#define VGA_ROTATE 0
std::string mraFilename = "Frogs.mra";
std::string tracefilename = "traces/frogs.tr";
#endif
#ifdef IS_HEIANKYO
#define VGA_ROTATE -1
std::string mraFilename = "Heiankyo Alien.mra";
std::string tracefilename = "traces/heiankyo.tr";
#endif
#ifdef IS_MISSILECIRCUIT
#define VGA_ROTATE -1
std::string mraFilename = "Missile + Circuit.mra";
#endif
#ifdef IS_NSUB
#define VGA_ROTATE -1
std::string mraFilename = "N-Sub.mra";
std::string tracefilename = "traces/nsub.tr";
#endif
#ifdef IS_SAFARI
#define VGA_ROTATE 0
std::string mraFilename = "Safari.mra";
std::string tracefilename = "traces/safari.tr";
#endif
#ifdef IS_SAMURAI
#define VGA_ROTATE -1
std::string mraFilename = "Samurai.mra";
std::string tracefilename = "traces/samurai.tr";
#endif
#ifdef IS_SPACEATTACK
#define VGA_ROTATE -1  
std::string mraFilename = "Space Attack.mra";
std::string tracefilename = "traces/spaceattack.tr";
#endif
#ifdef IS_SPACEATTACKHEADON
#define VGA_ROTATE -1  
std::string mraFilename = "Space Attack + Head On.mra";
#endif
#ifdef IS_SPACETREK
#define VGA_ROTATE -1
std::string mraFilename = "Space Trek.mra";
#endif
#ifdef IS_STARRAKER
#define VGA_ROTATE -1
std::string mraFilename = "Star Raker.mra";
#endif
#ifdef IS_SUBHUNT
#define VGA_ROTATE 0
std::string mraFilename = "Sub Hunt.mra";
#endif
#ifdef IS_TRANQUILIZERGUN
#define VGA_ROTATE -1
std::string mraFilename = "Tranquilizer Gun.mra";
std::string tracefilename = "traces/tranqgun.tr";
#endif
#ifdef IS_WANTED
#define VGA_ROTATE -1
std::string mraFilename = "Wanted.mra";
std::string tracefilename = "traces/wanted.tr";
#endif


// Video
// -----
#define VGA_WIDTH 256
#define VGA_HEIGHT 256
#define VGA_SCALE_X vga_scale
#define VGA_SCALE_Y vga_scale
SimVideo video(VGA_WIDTH, VGA_HEIGHT, VGA_ROTATE);
float vga_scale = 2.0;

// Audio
// -----	
//#define DISABLE_AUDIO
#ifndef DISABLE_AUDIO
SimAudio audio(clk_sys_freq, true);
#endif

// MAME debug log
//#define CPU_DEBUG

#ifdef CPU_DEBUG
bool log_instructions = true;
bool stop_on_log_mismatch = true;

std::vector<std::string> log_mame;
std::vector<std::string> log_cpu;
long log_index;
unsigned int ins_count = 0;

// CPU debug
bool cpu_sync;
bool cpu_sync_last;
std::vector<std::vector<std::string> > opcodes;
std::map<std::string, std::string> opcode_lookup;

bool writeLog(const char* line)
{
	// Write to cpu log
	log_cpu.push_back(line);

	// Compare with MAME log
	bool match = true;
	ins_count++;

	std::string c_line = std::string(line);
	std::string c = "%d > " + c_line + " ";

	//char buf[6];

	unsigned char in1 = top->emu__DOT__system__DOT__in_p1_data;
	unsigned char in2 = top->emu__DOT__system__DOT__in_p2_data;
	unsigned char in3 = top->emu__DOT__system__DOT__in_p3_data;
	unsigned char in4 = top->emu__DOT__system__DOT__in_p4_data;
	unsigned char acc = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__ACC;
	unsigned char vcnt = top->emu__DOT__system__DOT__vcnt;
	//c.append(fmt::format(" {0:02X} {1:02X} {2:02X} {3:02X} A={4:02X} Y={5}", in1, in2, in3, in4, acc, vcnt));
	c.append(fmt::format(" {0:02X} {1:02X} {2:02X} {3:02X} A={4:02X}", in1, in2, in3, in4, acc));

	if (log_index < log_mame.size()) {
		std::string m_line = log_mame.at(log_index);

		std::string m_line_lower = m_line.c_str();
		for (auto& c : m_line_lower) { c = tolower(c); }
		std::string c_line_lower = c_line.c_str();
		for (auto& c : c_line_lower) { c = tolower(c); }

		if (log_instructions) {
			console.AddLog(c.c_str(), ins_count);
		}
		if (stop_on_log_mismatch && m_line_lower != c_line_lower) {
			if (log_instructions) {
				std::string m = "MAME > " + m_line;
				console.AddLog(m.c_str());
			}
			console.AddLog("DIFF at %d", log_index);
			match = false;
			//console.LimitTo(10000);
			run_enable = 0;
		}
	}
	else {
		console.AddLog("MAME OUT");
		run_enable = 0;
	}

	log_index++;
	return match;

}

void loadOpcodes()
{
	std::string fileName = "z80_opcodes.csv";

	std::string                           header;
	std::ifstream                         reader(fileName);
	if (reader.is_open()) {
		std::string line, column, id;
		std::getline(reader, line);
		header = line;
		while (std::getline(reader, line)) {
			std::stringstream        ss(line);
			std::vector<std::string> columns;
			bool                     withQ = false;
			std::string              part{ "" };
			while (std::getline(ss, column, ',')) {
				auto pos = column.find("\"");
				if (pos < column.length()) {
					withQ = !withQ;
					part += column.substr(0, pos);
					column = column.substr(pos + 1, column.length());
				}
				if (!withQ) {
					column += part;
					columns.emplace_back(std::move(column));
					part = "";
				}
				else {
					part += column + ",";
				}
			}
			opcodes.push_back(columns);
			opcode_lookup[columns[0]] = columns[1];
		}
	}
};

std::string int_to_hex(unsigned char val)
{
	std::stringstream ss;
	ss << std::setfill('0') << std::setw(2) << std::hex << (val | 0);
	return ss.str();
}

std::string get_opcode(int ir, int ir_ext, int ir_superext)
{
	std::string hex = "0x";
	if (ir_superext > 0) {
		hex.append(int_to_hex(ir_superext));
	}
	if (ir_ext > 0) {
		hex.append(int_to_hex(ir_ext));
	}
	hex.append(int_to_hex(ir));
	if (opcode_lookup.find(hex) != opcode_lookup.end()) {
		return opcode_lookup[hex];
	}
	else
	{
		hex.append(" - MISSING OPCODE");
		return hex;
	}
}

bool hasEnding(std::string const& fullString, std::string const& ending) {
	if (fullString.length() >= ending.length()) {
		return (0 == fullString.compare(fullString.length() - ending.length(), ending.length(), ending));
	}
	else {
		return false;
	}
}

std::string last_log;

unsigned short last_pc;
unsigned short last_last_pc;
unsigned char last_mreq;

unsigned short active_pc;
unsigned char active_ir;
unsigned char active_ir_ext;
unsigned char active_ir_superext;
bool active_ir_valid = false;

const int ins_size = 48;
int ins_index = 0;
int ins_pc[ins_size];
int ins_in[ins_size];
int ins_ma[ins_size];
unsigned char active_ins = 0;
unsigned char last_acc;
unsigned char last_hcnt;
unsigned char last_vcnt;

bool vbl_last;
bool rom_read_last;

#endif


int verilate()
{

	if (!Verilated::gotFinish())
	{

		// Assert reset during startup
		if (main_time < initialReset) { top->RESET = 1; }
		// Deassert reset after startup
		if (main_time == initialReset) { top->RESET = 0; }

		// Clock dividers
		clk_vid.Tick();

		if (clk_vid.clk != clk_vid.old) {
			clk_sys.Tick();

			// Set system clock in core
			top->clk_sys = clk_sys.clk;

			// Simulate both edges of system clock
			if (clk_sys.clk != clk_sys.old) {
				if (clk_sys.clk) {
					// Handle HPS simulators
					input_0.BeforeEval();
					bus.BeforeEval();
					ddram.BeforeEval();
					sdram.BeforeEval();
				}
				top->eval();
				if (clk_sys.clk) {
					// Handle HPS simulators
					bus.AfterEval(); }
			}

			// Output pixels on rising edge of pixel clock
			if (clk_vid.IsFalling() && top->emu__DOT__ce_pix) {
				uint32_t colour = 0xFF000000 | top->VGA_B << 16 | top->VGA_G << 8 | top->VGA_R;
				video.Clock(top->VGA_HB, top->VGA_VB, top->VGA_HS, top->VGA_VS, colour);
			}

		}

#ifndef DISABLE_AUDIO
		if (clk_sys.IsRising())
		{
			audio.Clock(top->AUDIO_L, top->AUDIO_R);
		}
#endif


		if (clk_sys.IsRising()) {
#ifdef CPU_DEBUG
			if (!top->emu__DOT__system__DOT__reset) {


				unsigned short pc = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__PC;

				unsigned char di = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__di;
				unsigned short ad = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__A;
				unsigned char ir = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__IR;

				unsigned char acc = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__ACC;
				unsigned char z = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__flag_z;

				unsigned char hcnt = top->emu__DOT__system__DOT__hcnt;
				unsigned char vcnt = top->emu__DOT__system__DOT__vcnt;

				unsigned char phi = top->emu__DOT__system__DOT__cpu__DOT__cen;
				unsigned char mcycle = top->emu__DOT__system__DOT__cpu__DOT__mcycle;
				unsigned char mreq = top->emu__DOT__system__DOT__cpu__DOT__mreq_n;
				bool ir_changed = top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__ir_changed;

				bool rom_read = top->emu__DOT__system__DOT__rom_read;

				top->emu__DOT__system__DOT__cpu__DOT__i_tv80_core__DOT__ir_changed = 0;

				bool new_data = (mreq && !last_mreq && mcycle <= 4);
				bool rom_data = (!rom_read && rom_read_last);
				if ((rom_data) && !ir_changed) {
					std::string type = "NONE";
					if (new_data && !rom_data) { type = "NEW_ONLY"; }
					if (new_data && rom_data) { type = "BOTH_DATA"; }
					if (!new_data && rom_data) { type = "ROM_ONLY"; }
					//std::string message = "%08d > ";
					//message = message.append(type);
					//message = message.append(" PC=%04x IR=%02x AD=%04x DI=%02x");
					//console.AddLog(message.c_str(), main_time, pc, ir, ad, di);
					ins_in[ins_index] = di;
					ins_index++;
					if (ins_index > ins_size - 1) { ins_index = 0; }
				}
				//console.AddLog("%08d PC=%04x IR=%02x AD=%04x DI=%02x ACC=%d Z=%d ND=%d IRC=%d", main_time, pc, ir, ad, di, acc, z, new_data, ir_changed, acc);

				last_mreq = mreq;
				rom_read_last = rom_read;

				if (ir_changed) {
					//console.AddLog("%08d IR_CHANGED> PC=%04x IR=%02x AD=%04x DI=%02x ACC=%x z=%x", main_time, pc, ir, ad, di, acc, z);
					//console.AddLog("ACTIVE_IR: %x ACTIVE_PC: %x ACtIVE_IR_EXT: %x", active_ir, active_pc, active_ir_ext);

					if (active_ir_valid) {
						std::string opcode = get_opcode(active_ir, 0, 0);

						if (opcode.c_str() == "")
						{
							console.AddLog("No opcode found for %x", active_ir);
						}

						// Is this a compound opcode?
						size_t pos = opcode.find("****");
						if (pos != std::string::npos)
						{
							if (active_ir == 0xDD)
							{
								//								console.AddLog("SUPER! Compound opcode start: %s", opcode);
								active_ir_superext = active_ir;
							}
							else {
								//							console.AddLog("Compound opcode start: %s", opcode);
								active_ir_ext = active_ir;
							}
						}
						else {
							unsigned char data1 = ins_in[ins_index - 2];
							unsigned char data2 = ins_in[ins_index - 1];
							data1 = ins_in[0];
							data2 = ins_in[1];
							//std::string fmt = fmt::format("A={0:02X} X={1:03d} Y={2:03d} ", last_acc, last_hcnt, last_vcnt);
							//std::string fmt = fmt::format("A={0:02X} ", last_acc);
							std::string fmt;
							fmt.append("%04X: ");
							std::string opcode = get_opcode(active_ir, active_ir_ext, active_ir_superext);

							size_t pos = opcode.find("&0000");
							if (pos != std::string::npos)
							{
								//data1 = ins_in[0];
								//data2 = ins_in[1];
								//console.AddLog("&0000 %d %x %x %x", ins_index, ins_in[0], ins_in[1], ins_in[2]);
								char buf[6];
								sprintf(buf, "$%02X%02X", data2, data1);
								opcode.replace(pos, 5, buf);
							}

							pos = opcode.find("&4546");
							if (pos != std::string::npos)
							{
								//console.AddLog("&4546 %d %x %x %x", ins_index, ins_in[0], ins_in[1], ins_in[2]);
								char buf[6];
								unsigned char active_data = (ins_index == 1 ? data1 : data2);
								unsigned short add = active_pc + +2;
								if (opcode.substr(0, 4) == "djnz") {
									add = active_pc + ((signed char)active_data) + 2;
								}
								if (opcode.substr(0, 4) == "jr  ") {
									add = active_pc + ((signed char)active_data) + 2;
								}
								sprintf(buf, "$%04X", add);
								opcode.replace(pos, 5, buf);
							}

							pos = opcode.find("&00");
							if (pos != std::string::npos)
							{
								//console.AddLog("&00 %d %x %x %x", ins_index, ins_in[0], ins_in[1], ins_in[2]);
								char buf[4];
								sprintf(buf, "$%02X", ins_in[0]);
								opcode.replace(pos, 3, buf);

								pos = opcode.find("&00");
								if (pos != std::string::npos)
								{
									sprintf(buf, "$%02X", ins_in[1]);
									opcode.replace(pos, 3, buf);
								}
							}

							fmt.append(opcode);
							char buf[1024];
							sprintf(buf, fmt.c_str(), active_pc);
							writeLog(buf);

							// Clear instruction cache
							ins_index = 0;
							for (int i = 0; i < ins_size; i++) {
								ins_in[i] = 0;
								ins_ma[i] = 0;
							}
							if (active_ir_ext != 0) {
								active_ir_ext = 0;
								//		console.AddLog("Compound opcode cleared");
							}
							if (active_ir_superext != 0) {
								active_ir_superext = 0;
								//		console.AddLog("SUPER! Compound opcode cleared");
							}

							active_pc = ad;
						}
						last_acc = acc;
						last_hcnt = hcnt;
						last_vcnt = vcnt;
					}
					//console.AddLog("Setting active last_last_pc=%x last_pc=%x pc=%x addr=%x", last_last_pc, last_pc, pc, ad);
					active_ir_valid = true;
					ins_index = 0;
					active_ir = ir;

					last_last_pc = last_pc;
					last_pc = pc;
				}
			}
#endif
			main_time++;
		}
		return 1;
	}

	// Stop verilating and cleanup
	top->final();
	delete top;
	exit(0);
	return 0;
}

int main(int argc, char** argv, char** env)
{
	// Create core and initialise
	top = new Vemu();
	Verilated::commandArgs(argc, argv);

#ifdef WIN32
	// Attach debug console to the verilated code
	Verilated::setDebug(console);
#endif

#ifdef CPU_DEBUG
	// Load debug opcodes
	loadOpcodes();

	// Load debug trace
	std::string line;
	std::ifstream fin(tracefilename);
	while (getline(fin, line)) {
		log_mame.push_back(line);
	}
#endif

	// Attach HPS bus simulator
	bus.ioctl_addr = &top->ioctl_addr;
	bus.ioctl_index = &top->ioctl_index;
	bus.ioctl_wait = &top->ioctl_wait;
	bus.ioctl_download = &top->ioctl_download;
	//bus.ioctl_upload = &top->ioctl_upload;
	bus.ioctl_wr = &top->ioctl_wr;
	bus.ioctl_dout = &top->ioctl_dout;
	//bus.ioctl_din = &top->ioctl_din;
	//input.ps2_key = &top->ps2_key;

	// Attach HPS DDRAM simulator
	/*ddram.ddram_addr = &top->ddram_addr;
	ddram.ddram_rd = &top->ddram_rd;
	ddram.ddram_ack = &top->ddram_ack;
	ddram.ddram_dout = &top->ddram_dout;*/

	// Attach HPS SDRAM simulator
	sdram.sdram_addr = &top->sdram_addr;
	sdram.sdram_rd = &top->sdram_rd;
	sdram.sdram_wr = &top->sdram_wr;
	sdram.sdram_ack = &top->sdram_ack;
	sdram.sdram_dout = &top->sdram_dout;
	sdram.sdram_din = &top->sdram_din;


#ifndef DISABLE_AUDIO
	audio.Initialise();
#endif

	mem_edit_16.Cols = 32;

	// Set up input modules
	input_0.Initialise();
	input_1.Initialise();
#ifdef WIN32
	input_0.SetMapping(input_up, DIK_UP);
	input_0.SetMapping(input_right, DIK_RIGHT);
	input_0.SetMapping(input_down, DIK_DOWN);
	input_0.SetMapping(input_left, DIK_LEFT);
	input_0.SetMapping(input_fire1, DIK_RCONTROL);
	input_0.SetMapping(input_fire2, DIK_RSHIFT);
	input_0.SetMapping(input_fire3, DIK_SPACE);
	input_0.SetMapping(input_start1, DIK_1);
	input_0.SetMapping(input_start2, DIK_2);
	input_0.SetMapping(input_coin, DIK_5);
	input_0.SetMapping(input_dual_game_toggle, DIK_G);

	input_1.SetMapping(input_up, DIK_W);
	input_1.SetMapping(input_right, DIK_D);
	input_1.SetMapping(input_down, DIK_S);
	input_1.SetMapping(input_left, DIK_A);
	input_1.SetMapping(input_fire1, DIK_Z);
	input_1.SetMapping(input_fire2, DIK_X);
	input_1.SetMapping(input_fire3, DIK_C);
	input_1.SetMapping(input_start1, DIK_3);
	input_1.SetMapping(input_start2, DIK_4);
	input_1.SetMapping(input_coin, DIK_6);
#else
	//input.SetMapping(input_p1_up, SDL_SCANCODE_UP);
	//input.SetMapping(input_p1_right, SDL_SCANCODE_RIGHT);
	//input.SetMapping(input_p1_down, SDL_SCANCODE_DOWN);
	//input.SetMapping(input_p1_left, SDL_SCANCODE_LEFT);
	//input.SetMapping(input_p2_up, SDL_SCANCODE_W);
	//input.SetMapping(input_p2_right, SDL_SCANCODE_D);
	//input.SetMapping(input_p2_down, SDL_SCANCODE_S);
	//input.SetMapping(input_p2_left, SDL_SCANCODE_A);
	//input.SetMapping(input_coin, SDL_SCANCODE_5);
	//input.SetMapping(input_start1, SDL_SCANCODE_1);
	//input.SetMapping(input_start2, SDL_SCANCODE_2);
	//input.SetMapping(input_fire1, SDL_SCANCODE_RCTRL);
	//input.SetMapping(input_fire2, SDL_SCANCODE_LCTRL);
	//input.SetMapping(input_fire3, SDL_SCANCODE_SPACE);

#endif

	// Stage ROMs
	bus.LoadMRA("../releases/" + mraFilename);

	// Stage hiscore data
	bus.QueueDownload("./nvram/" + nvmFilename, 4, 0);

	// Setup video output
	if (video.Initialise(windowTitle) == 1) { return 1; }

#ifdef WIN32
	MSG msg;
	ZeroMemory(&msg, sizeof(msg));
	while (msg.message != WM_QUIT)
	{
		if (PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
			continue;
		}
#else
	bool done = false;
	while (!done)
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			ImGui_ImplSDL2_ProcessEvent(&event);
			if (event.type == SDL_QUIT)
				done = true;
		}
#endif
		video.StartFrame();

		input_0.Read();
		input_1.Read();


		// Draw GUI
		// --------
		ImGui::NewFrame();

		// Simulation control window
		ImGui::Begin(windowTitle_Control);
		ImGui::SetWindowPos(windowTitle_Control, ImVec2(0, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Control, ImVec2(500, 170), ImGuiCond_Once);
		if (ImGui::Button("Reset simulation")) { resetSim(); } ImGui::SameLine();
		if (ImGui::Button("Start running")) { run_enable = 1; } ImGui::SameLine();
		if (ImGui::Button("Stop running")) { run_enable = 0; } ImGui::SameLine();
		ImGui::Checkbox("RUN", &run_enable);
		//ImGui::PopItemWidth();
		ImGui::SliderInt("Run batch size", &batchSize, 1, 250000);
		if (single_step == 1) { single_step = 0; }
		if (ImGui::Button("Single Step")) { run_enable = 0; single_step = 1; }
		ImGui::SameLine();
		if (multi_step == 1) { multi_step = 0; }
		if (ImGui::Button("Multi Step")) { run_enable = 0; multi_step = 1; }
		//ImGui::SameLine();
		ImGui::SliderInt("Multi step amount", &multi_step_amount, 8, 1024);

		ImGui::Checkbox("Pause game", &pause_game); ImGui::SameLine();
		top->emu__DOT__pause_cpu = pause_game;

#ifdef CPU_DEBUG
		ImGui::NewLine();
		ImGui::Checkbox("Log CPU instructions", &log_instructions);
		ImGui::Checkbox("Stop on MAME diff", &stop_on_log_mismatch);
#endif
		ImGui::End();

		// Debug log window
		console.Draw(windowTitle_DebugLog, &showDebugLog, ImVec2(500, 700));
		ImGui::SetWindowPos(windowTitle_DebugLog, ImVec2(0, 160), ImGuiCond_Once);

		// Memory debug
		//ImGui::Begin("PGROM");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__pgrom__DOT__mem, 32768, 0);
		//ImGui::End();
		//ImGui::Begin("PROM1");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__prom1__DOT__mem, 32, 0);
		//ImGui::End();
		//ImGui::Begin("PROM2"); 
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__prom2__DOT__mem, 32, 0);
		//ImGui::End();
		//ImGui::Begin("COLPROM");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__colprom__DOT__mem, 32, 0);
		//ImGui::End();
		ImGui::Begin("RAM");
		mem_edit_16.DrawContents(&top->emu__DOT__system__DOT__ram__DOT__mem, 4096, 0);
		ImGui::End();
		//ImGui::Begin("97269-PR-02");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__sega_97269pb__DOT__pr02_a1__DOT__mem, 256, 0);
		//ImGui::End();
		//ImGui::Begin("97269-PR-56");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__sega_97269pb__DOT__pr56_b2__DOT__mem, 1024, 0);
		//ImGui::End();
		//ImGui::Begin("97269-PR-57");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__sega_97269pb__DOT__pr57_a3__DOT__mem, 1024, 0);
		//ImGui::End();

		//ImGui::Begin("MUSIC ROM");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__sound_carnival__DOT__rom_t48__DOT__mem, 1024, 0);
		//ImGui::End();
		//ImGui::Begin("SFX_LAST");
		//mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__wave__DOT__last_sample_ram__DOT__mem, 32, 0);
		//ImGui::End();
		// ImGui::Begin("AY Register");
		// mem_edit_8.DrawContents(&top->emu__DOT__system__DOT__sound_carnival__DOT__jt49_music__DOT__u_jt49__DOT__regarray, 16, 0);
		// ImGui::End();
		ImGui::Begin("HISCORE DATA");
		mem_edit_8.DrawContents(&top->emu__DOT__hi__DOT__hiscore_data__DOT__ram, 256, 0);
		ImGui::End();
		//ImGui::Begin("HISCORE BUFFER");
		//mem_edit_8.DrawContents(&top->emu__DOT__hi__DOT__hiscore_buffer__DOT__ram, 256, 0);
		//ImGui::End();

		//ImGui::Begin("HISCORE ADDRESS DATA");
		//mem_edit_8.DrawContents(&top->emu__DOT__hi__DOT__address_table__DOT__ram, 256, 0);
		//ImGui::End();

		int windowX = 550;
		int windowWidth = (VGA_WIDTH * VGA_SCALE_X) + 24;
		int windowHeight = (VGA_HEIGHT * VGA_SCALE_Y) + 90;

		// Video window
		ImGui::Begin(windowTitle_Video);
		ImGui::SetWindowPos(windowTitle_Video, ImVec2(windowX, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Video, ImVec2(windowWidth, windowHeight), ImGuiCond_Once);

		ImGui::SetNextItemWidth(400);
		ImGui::SliderFloat("Zoom", &vga_scale, 1, 8); ImGui::SameLine();
		ImGui::SetNextItemWidth(200);
		ImGui::SliderInt("Rotate", &video.output_rotate, -1, 1); ImGui::SameLine();
		ImGui::Checkbox("Flip V", &video.output_vflip);
		ImGui::Text("main_time: %d frame_count: %d sim FPS: %f", main_time, video.count_frame, video.stats_fps);

		// Draw VGA output
		ImGui::Image(video.texture_id, ImVec2(video.output_width * VGA_SCALE_X, video.output_height * VGA_SCALE_Y));
		ImGui::End();


#ifndef DISABLE_AUDIO
		windowWidth = 1000;
		ImGui::Begin(windowTitle_Audio);
		ImGui::SetWindowPos(windowTitle_Audio, ImVec2(windowX, windowHeight), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Audio, ImVec2(windowWidth, 250), ImGuiCond_Once);
		if (run_enable) {
			audio.CollectDebug((signed short)top->AUDIO_L, (signed short)top->AUDIO_R);
		}
		int channelWidth = (windowWidth / 2) - 16;
		ImPlot::CreateContext();
		if (ImPlot::BeginPlot("Audio - L", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_l, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImGui::SameLine();
		if (ImPlot::BeginPlot("Audio - R", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_r, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImPlot::DestroyContext();
		ImGui::End();
#endif

		video.UpdateTexture();

		// Pass inputs to sim
		top->joystick_0 = 0;
		for (int i = 0; i < input_0.inputCount; i++)
		{
			if (input_0.inputs[i]) { top->joystick_0 |= (1 << i); }
		}
		top->joystick_1 = 0;
		for (int i = 0; i < input_1.inputCount; i++)
		{
			if (input_1.inputs[i]) { top->joystick_1 |= (1 << i); }
		}

		// Run simulation
		if (run_enable) {
			for (int step = 0; step < batchSize; step++) { verilate(); }
		}
		else {
			if (single_step) { verilate(); }
			if (multi_step) {
				for (int step = 0; step < multi_step_amount; step++) { verilate(); }
			}
		}
	}

	// Clean up before exit
	// --------------------

#ifndef DISABLE_AUDIO
	audio.CleanUp();
#endif
	video.CleanUp();
	input_0.CleanUp();
	input_1.CleanUp();

	return 0;
}
