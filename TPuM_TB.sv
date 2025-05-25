`timescale 1ns / 1ps

//==================================================
// APB Slave Interface
//==================================================

interface APB_BUS;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [21:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  modport Slave (
    input  psel, penable, pwrite, paddr, pwdata,
    output prdata, pready, pslverr
  );
endinterface

//==================================================
// Testbench for TPUM_FSM
//==================================================
`timescale 1ns / 1ps

module TPUM_FSM_TB;

  // Clock and Reset
  logic clk = 0;
  logic rst_n = 0;

  always #5 clk = ~clk; // 100MHz clock

  // Instantiate APB interface
  APB_BUS apb_if();

  // Outputs from TPUM
    logic [1023:0] pum_XBOX_wdata ;
    logic pum_XBOX_rd, pum_XBOX_wr;
    logic [13:0] pum_XBOX_addr;
    logic [1023:0] pum_XBOX_rdata;

  // DUT
   TPUM_FSM dut (
    .clk(clk),
    .rst_n(rst_n),
    .apb(apb_if),
    .pum_XBOX_rdata(pum_XBOX_rdata),
    .pum_rd_from_XBOX(pum_XBOX_rd),
    .pum_wr_To_XBOX(pum_XBOX_wr),
    .pum_XBOX_addr(pum_XBOX_addr),
    .pum_XBOX_wdata(pum_XBOX_wdata)
  );

  // Task to do an APB write
  task automatic apb_write(input [31:0] addr, input [31:0] data);
    @(posedge clk);
    apb_if.paddr   <= addr;
    apb_if.pwdata  <= data;
    apb_if.psel    <= 1;
    apb_if.penable <= 0;
    apb_if.pwrite  <= 1;
    @(posedge clk);
    apb_if.penable <= 1;
    wait (apb_if.pready);
    @(posedge clk);
    apb_if.psel    <= 0;
    apb_if.penable <= 0;
  endtask

  // Task to do an APB read
  task automatic apb_read(input [31:0] addr, output [31:0] data);
    @(posedge clk);
    apb_if.paddr   <= addr;
    apb_if.psel    <= 1;
    apb_if.penable <= 0;
    apb_if.pwrite  <= 0;
    @(posedge clk);
    apb_if.penable <= 1;
    wait (apb_if.pready);
    data = apb_if.prdata;
    @(posedge clk);
    apb_if.psel    <= 0;
    apb_if.penable <= 0;
  endtask

  initial begin
    // Reset sequence
    rst_n <= 0;
    repeat (3) @(posedge clk);
    rst_n <= 1;
    @(posedge clk);

    $display("=== Testing Control Registers (0-7) ===");
    for (int i = 0; i <= 7; i++) begin
      apb_write(i << 2, 32'hA0000000 | i);
    end

    for (int i = 0; i <= 7; i++) begin
      logic [31:0] rdata;
      apb_read(i << 2, rdata);
      $display("CTRL[%0d] = 0x%08X", i, rdata);
    end

    $display("=== Testing Temp Registers (8–15) ===");
    for (int i = 8; i <= 15; i++) begin
      apb_write(i << 2, 32'hB0000000 | i);
    end

    for (int i = 8; i <= 15; i++) begin
      logic [31:0] rdata;
      apb_read(i << 2, rdata);
      $display("TEMP[%0d] = 0x%08X", i, rdata);
    end

    $display("=== Testing R1 Registers (16–47) ===");
    for (int i = 16; i <= 47; i++) begin
      apb_write(i << 2, 32'hC0000000 | i);
    end

    for (int i = 16; i <= 47; i++) begin
      logic [31:0] rdata;
      apb_read(i << 2, rdata);
      $display("R1[%0d] = 0x%08X", i - 16, rdata);
    end

    $display("=== Testing R2 Registers (48–79) ===");
    for (int i = 48; i <= 79; i++) begin
      apb_write(i << 2, 32'hD0000000 | i);
    end

    for (int i = 48; i <= 79; i++) begin
      logic [31:0] rdata;
      apb_read(i << 2, rdata);
      $display("R2[%0d] = 0x%08X", i - 48, rdata);
    end

    $display("=== Testing RA Registers (80–111) ===");
    for (int i = 80; i <= 111; i++) begin
      apb_write(i << 2, 32'hE0000000 | i);
    end

    for (int i = 80; i <= 111; i++) begin
      logic [31:0] rdata;
      apb_read(i << 2, rdata);
      $display("RA[%0d] = 0x%08X", i - 80, rdata);
    end

    $display("=== Test Complete ===");
    $finish;
  end

    

endmodule
