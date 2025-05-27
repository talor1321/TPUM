`timescale 1ns/1ps
module triple_pum (
    input clk,
    input rst_n,
    
    // APB interface
    APB_BUS.Slave     apb,         // APB slave interface bundling psel, penable, pwrite, etc.

    // xbox/PUM interface (preserved, but unused for now)
    input  [1023:0]   pum_xbox_rdata, // Input data from external memory
    output            pum_rd_from_xbox,    // Read enable signal to memory
    output            pum_wr_to_xbox,    // Write enable signal to memory
    output [13:0]     pum_xbox_addr,  // Memory address to read/write
    output [1023:0]   pum_xbox_wdata  // Data to write to memory
);

    typedef enum logic [5:0] {
        IDLE   = 6'b000001,
        INITR1 = 6'b000010,
        INITR2 = 6'b000100,
        GEMN   = 6'b001000,
        BNN    = 6'b010000,
        PUM    = 6'b100000
    } states;

    typedef enum logic [2:0] {
        GEMN_OP   = 3'b001,
        BNN_OP    = 3'b010,
        PUM_OP    = 3'b100
    } operations;

    assign pum_rd_from_xbox  = 1'b0;
    assign pum_wr_to_xbox = 1'b0;
    assign pum_xbox_addr = 14'b0; ///
    assign pum_xbox_wdata = 1024'b0;
    //==================================================
    // 2) Register file mapping
    // 0–7    : Control registers
    // 8      : Bypass register(from risc)
    // 9      : Done register
    // 10–15  : TEMP registers
    // 16–47  : R1 vector
    // 48–79  : R2 vector
    // 80–111 : RA vector
    //==================================================
    logic [31:0] rf_dim_a, rf_dim_b, rf_format, rf_tpum_mode;
    logic [31:0] rf_tpum_start, rf_base_pt_a, rf_base_pt_b, rf_base_pt_c;
    logic [31:0] rf_bypass_risc , rf_done;
    logic [31:0] temp_regs [0:6];
    // packed array
    logic [31:0] r1_words   [0:31];
    logic [31:0] r2_words   [0:31];
    logic [31:0] ra_words   [0:31];

    logic [5:0] state , next_state;
    
    //==================================================
    // 1) APB protocol setup phase: latch address and write enable
    //==================================================
    logic [6:0] apb_rf_index;     // Word-aligned index (up to 128 registers)

    assign apb_access = apb.psel && apb.penable ;
    assign apb_setup_wr = apb_access &&  apb.pwrite ;
    assign apb_setup_rd = apb_access && !apb.pwrite ;

    


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        apb_rf_index <= 7'd0;
        end else if (apb.psel && !apb.penable) begin
        apb_rf_index <= apb.paddr[8:2];  // Uses [8:2] → shift by 2 and drops bit 0 (APB must align to 4B)
        end
    end

    //==================================================
    // 3) Register write operation
    //==================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rf_dim_a <= 0; rf_dim_b <= 0; rf_format <= 0; rf_tpum_mode <= 0; rf_done <= 0;
            rf_tpum_start <= 0; rf_base_pt_a <= 0; rf_base_pt_b <= 0; rf_base_pt_c <= 0;rf_bypass_risc <=0;
            for (i = 0; i < 32; i++) begin
                r1_words[i] <= 0;
                r2_words[i] <= 0;
                ra_words[i] <= 0;
            end
            for (i = 0; i < 8; i++) begin
                temp_regs[i] <= 0;
            end

        end else if (apb_setup_wr) begin
            case (apb_rf_index)
                7'd0: rf_dim_a       <= apb.pwdata;
                7'd1: rf_dim_b       <= apb.pwdata;
                7'd2: rf_format      <= apb.pwdata;
                7'd3: rf_tpum_mode   <= apb.pwdata;
                7'd4: rf_tpum_start  <= apb.pwdata;
                7'd5: rf_base_pt_a   <= apb.pwdata;
                7'd6: rf_base_pt_b   <= apb.pwdata;
                7'd7: rf_base_pt_c   <= apb.pwdata;
                7'd8: rf_bypass_risc <= apb.pwdata;
                7'd9: rf_done <= apb.pwdata;
                default: begin
                if (apb_rf_index >= 10  && apb_rf_index <= 15)
                    temp_regs[apb_rf_index - 10] <= apb.pwdata;
                else if (apb_rf_index >= 16 && apb_rf_index <= 47)
                    r1_words[apb_rf_index - 16] <= apb.pwdata;
                else if (apb_rf_index >= 48 && apb_rf_index <= 79)
                    r2_words[apb_rf_index - 48] <= apb.pwdata;
                else if (apb_rf_index >= 80 && apb_rf_index <= 111)
                    ra_words[apb_rf_index - 80] <= apb.pwdata;
                end
            endcase
        end
    end


    //==================================================
    // 4) Register read multiplexer
    //==================================================
    logic [31:0] read_data;
    always_comb begin
        read_data = 32'd0;
        
        if (apb_setup_rd) begin
            case (apb_rf_index) 
                7'd0: read_data = rf_dim_a;
                7'd1: read_data = rf_dim_b;
                7'd2: read_data = rf_format;
                7'd3: read_data = rf_tpum_mode;
                7'd4: read_data = rf_tpum_start;
                7'd5: read_data = rf_base_pt_a;
                7'd6: read_data = rf_base_pt_b;
                7'd7: read_data = rf_base_pt_c;
                7'd8: read_data = rf_bypass_risc;
                7'd9: read_data = rf_done;
                default: begin
                  if (apb_rf_index >= 10  && apb_rf_index <= 15)
                      read_data = temp_regs[apb_rf_index - 10];
                  else if (apb_rf_index >= 16 && apb_rf_index <= 47)
                      read_data = r1_words[apb_rf_index - 16];
                  else if (apb_rf_index >= 48 && apb_rf_index <= 79)
                      read_data = r2_words[apb_rf_index - 48];
                  else if (apb_rf_index >= 80 && apb_rf_index <= 111)
                      read_data = ra_words[apb_rf_index - 80];
                  //else 
                      //read_data = x;
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end    
    end
    
    
    //==================================================
    // 7) XBOX/PUM interaction signals (reserved)
    //==================================================
    logic pum_xbox_reg_sel = 1'b1; // hardcoded selector: 1 for R1, 0 for R2
    logic [1023:0] ra_temp;

    // Write full 1024-bit to R1 or R2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        for (int i = 0; i < 32; i++) begin
            r1_words[i] <= 32'd0;
            r2_words[i] <= 32'd0;
        end
        end else if (pum_rd_from_xbox && !pum_wr_to_xbox) begin
        if (pum_xbox_sel) begin
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
        if (!pum_rd_from_xbox && pum_wr_to_xbox) begin
        for (int i = 0; i < 32; i++) begin
            ra_temp[i*32 +: 32] = ra_words[i];
        end
        end
    end

    assign pum_xbox_wdata = ra_temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end    
end

  always @(*) begin
      case (state)
          IDLE: begin
              next_state = IDLE;
              if (rf_tpum_start) begin
                next_state = LOADR1;
              end
          end

          LOADR1: begin
              next_state = LOADR2;
              pum_rd_from_xbox = 1'b1;
              pum_xbox_sel = 1'b1;
              pum_xbox_addr = 0;


            
          end

          LOADR1: begin
              next_state = state;
              pum_rd_from_xbox = 1'b1;
              pum_xbox_sel = 1'b1;
              pum_xbox_addr = 0;
              //if (xbox_read_ready) begin
              //    case (op_mode) 
              //        GEMM_OP: begin
              //            next_state = GEMM;
              //        end
        
              //        BNN_OP: begin
              //            next_state = BNN;
              //        end

              //        PUM_OP: begin
              //            next_state = PUM;
              //        end
              //    end  
              //end
          end
        
          GEMN: begin
        
          end
        
          BNN: begin
        
          end

          PUM: begin
        
          end


  end  
endmodule





    // always @(*) begin

    //     case (state)
    //         IDLE: begin
    //             //TODO: turn off all logic parts
    //         end

    //         INITR1: begin
    //             //if (xbox_read_ready) begin
    //             //    reg_r1_read_enable = 1;
    //             //    next_RF_curr_pt_a = RF_base_pt_a;
    //             //    //next_reg_r1 = XBOX[RF_base_pt_a];
    //             //end 
                
    //         end

    //         INITR2: begin
    //             //if (xbox_read_ready) begin
    //             //    reg_r2_read_enable = 1;
    //             //    next_RF_curr_pt_b = RF_base_pt_b;
    //             //    //next_reg_r2 = XBOX[RF_base_pt_b];
    //             //end
    //         end
            
    //         GEMN: begin
            
    //         end
            
    //         BNN: begin
            
    //         end

    //         PUM: begin
            
    //         end


    // end
