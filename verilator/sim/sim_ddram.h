#pragma once
#include "verilated_heavy.h"
#include "sim_console.h"

struct SimDDRAM {
public:

	IData* ddram_addr;
	CData* ddram_dout;
	CData* ddram_rd;
	CData* ddram_ack;

	std::vector<char> mem;

	void BeforeEval(void);

	void Write(long address, char data);

	SimDDRAM(DebugConsole c, long start, long size);
	~SimDDRAM();

};
