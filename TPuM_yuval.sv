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
        IDLE   = 7'b0000001,
        LOADR1 = 7'b0000010,
        LOADR2 = 7'b0000100,
        GEMN   = 7'b0001000,
        BNN    = 7'b0010000,
        PUM    = 7'b0100000,
        DONE   = 7'b1000000
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
    // 10      : state register
    // 11–15  : TEMP registers
    // 16–47  : R1 vector
    // 48–79  : R2 vector
    // 80–111 : RA vector
    //==================================================
    logic [31:0] rf_format, rf_tpum_mode;
    logic [31:0] rf_dim_a_ver, rf_dim_a_hor;
    logic [31:0] rf_dim_b_ver, rf_dim_b_hor;
    logic [31:0] rf_tpum_start, rf_base_pt_a, rf_base_pt_b, rf_base_pt_c;
    logic [31:0] rf_bypass_risc , rf_done, rf_state; 
    logic [31:0] temp_regs [0:5];
    // packed array
    logic [31:0] r1_words   [0:31];
    logic [31:0] r2_words   [0:31];
    logic [31:0] ra_words   [0:31];
    logic [31:0] next_ra_words   [0:31];

    logic [6:0] state , next_state;
    logic [14:0] counter_input_dim , next_counter_input_dim;
    logic [14:0] counter_weights , next_counter_weights;
    

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
            rf_dim_a_ver <= 0; rf_dim_b_ver <= 0; rf_dim_a_hor <= 0; rf_dim_b_hor <= 0; 
            rf_format <= 0; rf_tpum_mode <= 0; rf_done <= 0;
            rf_tpum_start <= 0; rf_base_pt_a <= 0; rf_base_pt_b <= 0; rf_base_pt_c <= 0;rf_bypass_risc <=0;
            rf_state <= IDLE;
            for (i = 0; i < 32; i++) begin
                r1_words[i] <= 0;
                r2_words[i] <= 0;
                //ra_words[i] <= 0;
            end
            for (i = 0; i < 5; i++) begin
                temp_regs[i] <= 0;
            end

        end else if (apb_setup_wr) begin
            case (apb_rf_index)
                7'd0: rf_dim_a_ver       <= apb.pwdata;
                7'd1: rf_dim_b_ver       <= apb.pwdata;
                7'd2: rf_dim_a_hor       <= apb.pwdata;
                7'd3: rf_dim_b_hor       <= apb.pwdata;
                7'd4: rf_format      <= apb.pwdata;
                7'd5: rf_tpum_mode   <= apb.pwdata;
                7'd6: rf_tpum_start  <= apb.pwdata;
                7'd7: rf_base_pt_a   <= apb.pwdata;
                7'd8: rf_base_pt_b   <= apb.pwdata;
                7'd9: rf_base_pt_c   <= apb.pwdata;
                7'd10: rf_bypass_risc <= apb.pwdata;
                7'd11: rf_done        <= apb.pwdata;
                default: begin // 13 because rf_state is 12
                if (apb_rf_index >= 13  && apb_rf_index <= 15)
                    temp_regs[apb_rf_index - 13] <= apb.pwdata;
                else if (apb_rf_index >= 16 && apb_rf_index <= 47)
                    r1_words[apb_rf_index - 16] <= apb.pwdata;
                else if (apb_rf_index >= 48 && apb_rf_index <= 79)
                    r2_words[apb_rf_index - 48] <= apb.pwdata;
                //else if (apb_rf_index >= 80 && apb_rf_index <= 111)
                //    ra_words[apb_rf_index - 80] <= apb.pwdata;
                end
            endcase
        end
    end


    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ra_words <= 0;
        end else begin
            ra_words <= next_ra_words;  
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
                7'd0: read_data  = rf_dim_a_ver;
                7'd1: read_data  = rf_dim_b_ver;
                7'd2: read_data  = rf_dim_a_hor;
                7'd3: read_data  = rf_dim_b_hor;
                7'd4: read_data  = rf_format;
                7'd5: read_data  = rf_tpum_mode;
                7'd6: read_data  = rf_tpum_start;
                7'd7: read_data  = rf_base_pt_a;
                7'd8: read_data  = rf_base_pt_b;
                7'd9: read_data  = rf_base_pt_c;
                7'd10: read_data  = rf_bypass_risc;
                7'd11: read_data  = rf_done;
                7'd12: read_data = rf_state;
                
                default: begin
                  if (apb_rf_index >= 13  && apb_rf_index <= 15)
                      read_data = temp_regs[apb_rf_index - 13];
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

    //==================================================
    // 8) States Registers
    //==================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end    
    end

    //==================================================
    // 9) Counters Registers
    //==================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_weights <= 0;
            counter_input_dim <= 0;
        end else begin
            counter_weights <= next_counter_weights;
            counter_input_dim <= next_counter_input_dim;
        end    
    end
    
    //==================================================
    // Calculating the next state
    //==================================================
    always_comb begin
        case (state)
            IDLE: begin
                next_state = IDLE;

                if (rf_tpum_start) begin
                next_state = LOADR2;
                end
            end

            LOADR2: begin
                next_state = LOADR1;
        
            end

            LOADR1: begin
                next_state = state;

                case (rf_tpum_mode[2:0])
                    GEMM_OP: begin
                        next_state = GEMN;
                    end
                    BNN_OP: begin
                        next_state = BNN;
                    end
                    PUM_OP: begin
                        next_state = PUM;
                    end
                    default: begin
                        // optional : add an error state
                        next_state = 3'bx;
                    end
                endcase
            end
        
            GEMN: begin
        
            end
        
            BNN: begin
                
                // the user should write the inputs as is(784 and not 783)
                if (counter_input_dim < rf_dim_a_ver) begin
                    // bring the next R1
                    next_state = LOADR1;
                end else begin
                    if (counter_weights < rf_dim_b_ver) begin
                        // it means that we need to bring the next R2
                        next_state = LOADR2;
                    end else begin
                        next_state = DONE;
                        // set the next_rf_done register to 1
                    end
                        
                end
            end

            PUM: begin
        
            end

            DONE: begin

            end
    end 

    //==================================================
    // states logic
    //==================================================
    always_comb begin
        next_counter_input_dim = counter_input_dim;
        next_counter_weights = counter_weights;
        pum_rd_from_xbox = 0;
        pum_wr_to_xbox = 0;

        case (state)
            IDLE: begin
                next_counter_input_dim = 0;
                next_counter_weights = 0;
            end

            LOADR2: begin
                pum_rd_from_xbox = 1'b1;
                pum_xbox_sel = 1'b0; // R2
                //pum_xbox_addr = 0;
                pum_xbox_addr = rf_base_pt_b + counter_weights;
                next_counter_weights = counter_weights + 1;
                next_counter_input_dim = 0;
            end

            LOADR1: begin
                pum_rd_from_xbox = 1'b1;
                pum_xbox_sel = 1'b1; // R1
                //pum_xbox_addr = 0;
                //pum_xbox_addr = rf_base_pt_a + 1024 * counter_input_dim;
                pum_xbox_addr = rf_base_pt_a + counter_input_dim;
                next_counter_input_dim = counter_input_dim + 1;


            
            end
        
            GEMN: begin
        
            end
        
            BNN: begin
                next_ra_words = 1024'd12;
            end

            PUM: begin
        
            end
            
            DONE: begin
                pum_wr_to_xbox = 1'b1; 
            end
    end 


  // Monitoring
  //...
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
