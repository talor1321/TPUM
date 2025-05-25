`timescale 1ns / 1ps

// TPUM_FSM: TriplePuM controller with APB register access
// Handles 1024-bit operand registers (R1, R2) and result register (RA) using 32x32-bit words
module TPUM_FSM (
  input             clk,         // Clock signal
  input             rst_n,       // Active-low reset

  // APB interface
  APB_BUS.Slave     apb,         // APB slave interface bundling psel, penable, pwrite, etc.

  // XBOX/PUM interface (preserved, but unused for now)
  input  [1023:0]   pum_XBOX_rdata, // Input data from external memory
  output            pum_rd_from_XBOX,    // Read enable signal to memory
  output            pum_wr_To_XBOX,    // Write enable signal to memory
  output [13:0]     pum_XBOX_addr,  // Memory address to read/write
  output [1023:0]   pum_XBOX_wdata  // Data to write to memory
);

  //==================================================
  // 1) APB protocol setup phase: latch address and write enable
  //==================================================
  logic [6:0] apb_RF_index;     // Word-aligned index (up to 128 registers)

  assign apb_setup_wr = apb.psel &&  apb.pwrite  ;
  assign apb_setup_rd = apb.psel && !apb.pwrite  ;
  assign apb_access = apb.psel && apb.penable ;


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      apb_RF_index <= 7'd0;
    end else if (apb.psel && !apb.penable) begin
      apb_RF_index <= apb.paddr[7:1];  // Uses [7:1] → shift by 2 and drops bit 0 (APB must align to 4B)
    end
  end

  //==================================================
  // 2) Register file mapping
  // 0–7    : Control registers
  // 8–15   : TEMP registers
  // 16–47  : R1 vector
  // 48–79  : R2 vector
  // 80–111 : RA vector
  //==================================================
  logic [31:0] RF_dim_a, RF_dim_b, RF_format, RF_tpum_mode;
  logic [31:0] RF_tpum_start, RF_base_pt_a, RF_base_pt_b, RF_base_pt_c;
  logic [31:0] temp_regs [0:7];
  // packed array
  logic [31:0] r1_words   [0:31];
  logic [31:0] r2_words   [0:31];
  logic [31:0] ra_words   [0:31];

  //==================================================
  // 3) Register write operation
  //==================================================
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      RF_dim_a <= 0; RF_dim_b <= 0; RF_format <= 0; RF_tpum_mode <= 0;
      RF_tpum_start <= 0; RF_base_pt_a <= 0; RF_base_pt_b <= 0; RF_base_pt_c <= 0;
      for (i = 0; i < 32; i++) begin
        r1_words[i] <= 0;
        r2_words[i] <= 0;
        ra_words[i] <= 0;
      end
      for (i = 0; i < 8; i++) begin
        temp_regs[i] <= 0;
      end
    end else if (apb_setup_wr) begin
      case (apb_RF_index)
        7'd0: RF_dim_a      <= apb.pwdata;
        7'd1: RF_dim_b      <= apb.pwdata;
        7'd2: RF_format     <= apb.pwdata;
        7'd3: RF_tpum_mode  <= apb.pwdata;
        7'd4: RF_tpum_start <= apb.pwdata;
        7'd5: RF_base_pt_a  <= apb.pwdata;
        7'd6: RF_base_pt_b  <= apb.pwdata;
        7'd7: RF_base_pt_c  <= apb.pwdata;
        default: begin
          if (apb_RF_index >= 8  && apb_RF_index <= 15)
            temp_regs[apb_RF_index - 8] <= apb.pwdata;
          else if (apb_RF_index >= 16 && apb_RF_index <= 47)
            r1_words[apb_RF_index - 16] <= apb.pwdata;
          else if (apb_RF_index >= 48 && apb_RF_index <= 79)
            r2_words[apb_RF_index - 48] <= apb.pwdata;
          else if (apb_RF_index >= 80 && apb_RF_index <= 111)
            ra_words[apb_RF_index - 80] <= apb.pwdata;
        end
      endcase
    end
  end

  //==================================================
  // 4) Register read multiplexer
  //==================================================
  logic [31:0] read_data;
  always @(*) begin
    read_data = 32'd0;
    if (apb_access) begin
      case (apb_RF_index)
        7'd0: read_data = RF_dim_a;
        7'd1: read_data = RF_dim_b;
        7'd2: read_data = RF_format;
        7'd3: read_data = RF_tpum_mode;
        7'd4: read_data = RF_tpum_start;
        7'd5: read_data = RF_base_pt_a;
        7'd6: read_data = RF_base_pt_b;
        7'd7: read_data = RF_base_pt_c;
        default: begin
          if (apb_RF_index >= 8  && apb_RF_index <= 15)
            read_data = temp_regs[apb_RF_index - 8];
          else if (apb_RF_index >= 16 && apb_RF_index <= 47)
            read_data = r1_words[apb_RF_index - 16];
          else if (apb_RF_index >= 48 && apb_RF_index <= 79)
            read_data = r2_words[apb_RF_index - 48];
          else if (apb_RF_index >= 80 && apb_RF_index <= 111)
            read_data = ra_words[apb_RF_index - 80];
        end
      endcase
    end
  end

  //==================================================
  // 5) Drive APB response signals
  //==================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      apb.prdata  <= 32'd0;
      apb.pready  <= 1'b0;
      apb.pslverr <= 1'b0;
    end else begin
      apb.pready  <= apb_access;
      apb.prdata  <= read_data;
      apb.pslverr <= 1'b0;  // No error reporting
    end
  end

  //==================================================
  // 6) Output flattened vectors (optional use)
  //==================================================
  // logic [1023:0] reg_r1 = {<<{r1_words}};  // Flattened R1
  // logic [1023:0] reg_r2 = {<<{r2_words}};  // Flattened R2
  // logic [1023:0] reg_ra = {<<{ra_words}};  // Flattened RA

  //==================================================
  // 7) XBOX/PUM interaction signals (reserved)
  //==================================================
  logic pum_XBOX_sel = 1'b1; // hardcoded selector: 1 for R1, 0 for R2
  logic [1023:0] ra_temp;

  // Write full 1024-bit to R1 or R2
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) begin
        r1_words[i] <= 32'd0;
        r2_words[i] <= 32'd0;
      end
    end else if (pum_rd_from_XBOX && !pum_wr_To_XBOX) begin
      if (pum_XBOX_sel) begin
        for (int i = 0; i < 32; i++) begin
          r1_words[i] <= pum_XBOX_rdata[i*32 +: 32];
        end
      end else begin
        for (int i = 0; i < 32; i++) begin
          r2_words[i] <= pum_XBOX_rdata[i*32 +: 32];
        end
      end
    end
  end

  // Read full 1024-bit from RA using intermediate logic
  always_comb begin
    ra_temp = 1024'd0;
    if (pum_rd_from_XBOX && !pum_wr_To_XBOX) begin
      for (int i = 0; i < 32; i++) begin
        ra_temp[i*32 +: 32] = ra_words[i];
      end
    end
  end

  assign pum_XBOX_wdata = ra_temp;

endmodule