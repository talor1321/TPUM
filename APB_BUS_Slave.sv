// APB_BUS_if.sv
// SystemVerilog interface for APB Slave

`timescale 1ns/1ps

interface APB_BUS_Slave;
    // APB slave-side signals
    logic        psel;      // Select peripheral
    logic        penable;   // Enable transfer (apb_access phase)
    logic        pwrite;    // 1 = write, 0 = read
    logic [6:0] paddr;     // Address bus (7-bit)
    logic [31:0] pwdata;    // Write data bus
    logic [31:0] prdata;    // Read data bus (output from slave)
    logic        pready;    // Slave ready signal // may not exist in all APB implementations
    logic        pslverr;   // Slave error signal // may not exist in all APB implementations

    // Modport for slave apb_access
    modport Slave (
        input  psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr
    );
endinterface