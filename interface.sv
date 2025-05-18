module rm_example (
    input                 clk,
    input                 rst_n,
    input [16*8*5-1:0]    ram_ctrl, // 16x8 instances of 1024x128 mem, 5 control bits per memory macro (TSMC 65)
                          APB_BUS.Slave apb,
    input [13:0]          pum_mem_addr,
    input [1023:0]        pum_mem_wdata,
    input                 pum_mem_rd,
    input                 pum_mem_wr,
    output [1023:0]       pum_mem_rdata

);


// address space is 4MB (22 address bits)
// memory is 2MB
// memory starts at address BASE
// uppermost 2MB block is for registers = BASE+0x200000

 logic [31:0][31:0] rm_example_regs;
 logic [31:0] regs_rd_data_out ;
 logic ready ;
 logic [21:0] rm_example_addr ;
 logic is_rm_example_reg_addr ;
 logic is_rm_example_mem_addr;
 logic [5:0] reg_idx ;
 logic apb_setup_wr   ;
 logic apb_setup_rd  ;
 logic apb_access ;
 logic apb_wr_reg ;
 logic regs_rd_access ;
 logic is_regs_data_out ;

 assign rm_example_addr = apb.paddr[21:0];
 assign is_rm_example_reg_addr = apb.psel && rm_example_addr[21:21] == 1'b1;
 assign is_rm_example_mem_addr = apb.psel && rm_example_addr[21:21] != 1'b1;
 assign reg_idx = rm_example_addr[6:2];
 assign apb_setup_wr = apb.psel &&  apb.pwrite  ;
 assign apb_setup_rd = apb.psel && !apb.pwrite  ;
 assign apb_access = apb.psel && apb.penable ;
 assign apb_wr_reg = apb_setup_wr && is_rm_example_reg_addr && !ready ;
 assign regs_rd_access = apb_setup_rd && is_rm_example_reg_addr && !ready ;

 // REGS WRITE
 always @(posedge clk, negedge rst_n)
     if(~rst_n)
       for (int i=0;i<32;i++) rm_example_regs[i] <= 0 ;
     else

       if (apb_wr_reg) rm_example_regs[reg_idx] <= apb.pwdata;

  // REGS SYNCHRONOUS READ
 always @(posedge clk)
   if  (regs_rd_access) regs_rd_data_out <= rm_example_regs[reg_idx] ;

 // indicate regs read output
 always @(posedge clk, negedge rst_n)
     if (~rst_n) is_regs_data_out <= 0 ;
     else is_regs_data_out <= regs_rd_access ;

 //=====================================================
 // APB Memory access

logic mem_rden ;
logic mem_wren ;
logic [3:0][31:0] p_mem_data_out ;

assign mem_rden  = apb_setup_rd && is_rm_example_mem_addr && !ready;
assign mem_wren  = apb_setup_wr && is_rm_example_mem_addr && !ready;

 generate
     genvar i;
       for (i = 0; i < 4; i = i + 1) begin : mem_inst
   rm_example_mem rm_example_mem (
                .clk      (clk),
                .rst_n    (rst_n),
                .ram_ctrl (ram_ctrl[16*2*5*(i+1)-1:16*2*5*i]),

                // Host (APB) port interface
                .p_addr     ({apb.paddr[20:7],apb.paddr[4:0]}),
                .p_data_in  (apb.pwdata[31:0]),
                .p_rd       (mem_rden&(apb.paddr[6:5]==i)),
                .p_wr       (mem_wren&(apb.paddr[6:5]==i)),
                .p_data_out (p_mem_data_out[i]),
                .p_done     (), // TMP NOT YET IN USE

                // XBOX HW accelerator interface

                .pum_mem_addr(pum_mem_addr),
                .pum_mem_wdata(pum_mem_wdata[256*(i+1)-1:256*i]),
                .pum_mem_rd(pum_mem_rd),
                .pum_mem_wr(pum_mem_wr),
                .pum_mem_rdata(pum_mem_rdata[256*(i+1)-1:256*i])
                );
      end
 endgenerate



 //=====================================================

  // apb.prdata output mux

  assign apb.prdata = is_regs_data_out ? regs_rd_data_out : p_mem_data_out[apb.paddr[6:5]] ;

  //====================================================

  // READY HANDLING
  always @(posedge clk, negedge rst_n)
     if(~rst_n)
       ready <= 0 ;
     else
       ready <= apb.psel ;

  assign apb.pready = ready && apb.penable ;

  // ERROR HANDLING
  assign apb.pslverr = 1'b0; // not supporting transfer failure



endmodule
 //=========================================================

 // Verilog debug assistance Messages
/*
 logic [17:0] addr_s ;
 logic [31:0] wr_data_s ;
 logic write_s ;
 logic is_xbox_reg_addr_s ;


 always @(posedge clk) begin

       addr_s <= apb.paddr[17:0] ;
       wr_data_s <= apb.pwdata ;
       write_s <= apb.pwrite;
       is_xbox_reg_addr_s <= is_xbox_reg_addr ;

       if (apb.pready) begin
          if (is_xbox_reg_addr_s) begin
             if (write_s) $display($time," VERILOG MSG: GPP XBOX APB Writing %x to xbox_regs[%02d]",wr_data_s,addr_s[7:2]) ;
             else         $display($time," VERILOG MSG: GPP XBOX APB Reading %x from (xbox_regs[%02d])",apb.prdata,addr_s[7:2]) ;
          end
       end

 end
*/

endmodule

// OUR DESIGN
TPUM_FSM tpum_test (
    .clk           (clk),
    .rst_n         (rst_n),
    .xbox_rd        (pum_mem_rd),
    .xbox_wr        (pum_mem_wr),
    .xbox_addr      (pum_mem_addr),
    .xbox_data     (pum_mem_wdata),
    .xbox_data     (pum_mem_rdata)
  );