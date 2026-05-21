#include <iostream>
#include <memory>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtop.h"

int main(int argc, char** argv) {
    // Initialize Verilator context
    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);
    context->traceEverOn(true);
    
    // Create an instance of our module under test
    auto top = std::make_unique<Vtop>(context.get());

    // Setup VCD tracing
    auto tfp = std::make_unique<VerilatedVcdC>();
    top->trace(tfp.get(), 99);
    tfp->open("trace.vcd");

    // Initial state
    top->clk = 0;
    top->rst = 1; // Assert reset
    top->eval();
    tfp->dump(context->time());
    context->timeInc(1);

    std::cout << "Starting Verilator simulation for Diablo..." << std::endl;

    // Run 2 cycles with reset asserted
    for (int i = 0; i < 4; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(context->time());
        context->timeInc(1);
    }

    // Deassert reset and run pipeline
    top->rst = 0;
    for (int i = 0; i < 40; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(context->time());
        context->timeInc(1);
        
        if (Verilated::gotFinish()) {
            break;
        }
    }

    std::cout << "Simulation finished. Waveform dumped to trace.vcd" << std::endl;
    
    // Cleanup
    tfp->close();
    return 0;
}
