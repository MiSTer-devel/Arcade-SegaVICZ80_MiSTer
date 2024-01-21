#include "sim_ddram.h"
#include "verilated_heavy.h"
#include "sim_console.h"

static DebugConsole console;

IData* ddram_addr = NULL;
CData* ddram_dout = NULL;
CData* ddram_rd = NULL;
CData* ddram_ack = NULL;

long area_start;
long area_size;

long ddram_addr_last = 0;

void SimDDRAM::Write(long address, char data) {
	long a = address - area_start;
	mem[a] = data;
}

void SimDDRAM::BeforeEval()
{
	if (ddram_rd != NULL) {
		if (*ddram_rd)
		{
			long a = *ddram_addr;
			*ddram_dout = mem[a];
			//if (ddram_addr_last!= *ddram_addr) { 
				//console.AddLog("DDRAM RD %d = %x", *ddram_addr, *ddram_dout); 
			//}
			*ddram_ack = ~*ddram_ack;
		}
		ddram_addr_last = *ddram_addr;
	}
}

SimDDRAM::SimDDRAM(DebugConsole c, long start, long size) {
	console = c;
	ddram_addr = NULL;
	ddram_dout = NULL;
	ddram_rd = NULL;
	ddram_ack = NULL;
	area_start = start;
	area_size = size;
	mem.resize(size);
}

SimDDRAM::~SimDDRAM() {

}
