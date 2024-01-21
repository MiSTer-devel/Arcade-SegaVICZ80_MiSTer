#include "sim_sdram.h"
#include "verilated_heavy.h"
#include "sim_console.h"

static DebugConsole console;

IData* sdram_addr = NULL;
CData* sdram_dout = NULL;
CData* sdram_din = NULL;
CData* sdram_rd = NULL;
CData* sdram_wr = NULL;
CData* sdram_ack = NULL;

long sdram_addr_last = 0;
int size = 128 * 1024 * 1024;

void SimSDRAM::BeforeEval()
{
	if (*sdram_rd)
	{
		long a = *sdram_addr;
		unsigned char c = mem[a];
		//console.AddLog("SDRAM: %d > %x", a, c);
		*sdram_dout = c;
		*sdram_ack = ~*sdram_ack;
	}
	if (*sdram_wr)
	{
		long a = *sdram_addr;
		unsigned char c = *sdram_din;
		mem[a] = c;
		*sdram_ack = ~*sdram_ack;
	}
	sdram_addr_last = *sdram_addr;
}

SimSDRAM::SimSDRAM(DebugConsole c) {
	console = c;
	sdram_addr = NULL;
	sdram_dout = NULL;
	sdram_din = NULL;
	sdram_rd = NULL;
	sdram_wr = NULL;
	sdram_ack = NULL;
	mem.resize(size);
}

SimSDRAM::~SimSDRAM() {

}
