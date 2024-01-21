#pragma once
#include "verilated_heavy.h"
#include "sim_console.h"

struct SimSDRAM {
public:

	IData* sdram_addr;
	CData* sdram_dout;
	CData* sdram_din;
	CData* sdram_rd;
	CData* sdram_wr;
	CData* sdram_ack;

	std::vector<char> mem;

	void BeforeEval(void);

	SimSDRAM(DebugConsole c);
	~SimSDRAM();

};
