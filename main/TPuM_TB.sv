`timescale 1ns / 1ps

//==================================================
// APB Slave Interface
//==================================================
interface APB_BUS;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [8:0]  paddr;
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
module triple_pum_tb();

  // Clock and Reset
  logic clk = 0;
  logic rst_n = 0;

  always #5 clk = ~clk; // 100MHz clock

  // Instantiate APB interface
  APB_BUS apb_if();

  // Outputs from TPUM
  logic [1023:0] pum_xbox_wdata ;
  logic pum_xbox_rd, pum_xbox_wr;
  logic [13:0] pum_xbox_addr;
  logic [1023:0] pum_xbox_rdata;

  // Declare reg11_data inside the module
  reg [31:0] reg12_data;

  // DUT
  triple_pum dut (
    .clk(clk),
    .rst_n(rst_n),
    .apb(apb_if),
    .pum_xbox_rdata(pum_xbox_rdata),
    .pum_rd_from_xbox(pum_xbox_rd),
    .pum_wr_to_xbox(pum_xbox_wr),
    .pum_xbox_addr(pum_xbox_addr),
    .pum_xbox_wdata(pum_xbox_wdata)
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

    // $display("=== Testing Control Registers (0-7) ===");
    // for (int i = 0; i <= 7; i++) begin
    //   apb_write(i << 2, 32'hA0000000 | i);
    // end

    // for (int i = 0; i <= 7; i++) begin
    //   logic [31:0] rdata;
    //   apb_read(i << 2, rdata);
    //   $display("CTRL[%0d] = 0x%08X", i, rdata);
    // end

    // $display("=== Testing Temp Registers (8–15) ===");
    // for (int i = 8; i <= 15; i++) begin
    //   apb_write(i << 2, 32'hB0000000 | i);
    // end

    // for (int i = 8; i <= 15; i++) begin
    //   logic [31:0] rdata;
    //   apb_read(i << 2, rdata);
    //   $display("TEMP[%0d] = 0x%08X", i, rdata);
    // end
/*
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

*/



    // Write the dimensions for BNN (for example, dim_a_ver = 10, dim_b_ver = 10)
    apb_write(7'd0 << 2, 32'd10);  // rf_dim_a_ver
    apb_write(7'd1 << 2, 32'd10);  // rf_dim_b_ver

    // Set the mode to BNN_OP (rf_tpum_mode = 3'b010)
    apb_write(7'd5 << 2, 32'b0000000000000000000000000000010);  // rf_tpum_mode = BNN_OP
    // Read from reg11 before completing the test
    apb_read(12 << 2, reg12_data);  // Reading from reg11 (address 11)

    // Display the read data from reg11
    apb_write(7'd6 << 2, 32'd1);  // rf_tpum_start
  
    pum_xbox_rdata = 1024'hA1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1; 

    // Read from reg11 before completing the test
    apb_read(12 << 2, reg12_data);  // Reading from reg11 (address 11)

    // Display the read data from reg11
    $display("Data from reg12: %h", reg12_data);
    #3000
    // Read from reg11 before completing the test
    apb_read(12 << 2, reg12_data);  // Reading from reg11 (address 11)

    // Display the read data from reg11
    $display("Data from reg12: %h", reg12_data);


    apb_read(11 << 2, reg12_data);  // Reading from reg11 (address 11)

    // Display the read data from reg11
    $display("Data from reg11: %h", reg12_data);

    $display("=== Test Complete ===");
    $finish;
  end

endmodule
