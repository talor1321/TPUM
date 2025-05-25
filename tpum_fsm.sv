module TPUM_FSM (
    input clk,
    input rst_n,
    
    // APB interface
    APB_BUS.Slave     apb,         // APB slave interface bundling psel, penable, pwrite, etc.

    // XBOX/PUM interface (preserved, but unused for now)
    input  [1023:0]   pum_XBOX_rdata, // Input data from external memory
    output            pum_rd_from_XBOX,    // Read enable signal to memory
    output            pum_wr_To_XBOX,    // Write enable signal to memory
    output [13:0]     pum_XBOX_addr,  // Memory address to read/write
    output [1023:0]   pum_XBOX_wdata  // Data to write to memory
);

    typedef enum logic [5:0] {
        IDLE   = 6'b000001;
        INITR1 = 6'b000010;
        INITR2 = 6'b000100;
        GEMN   = 6'b001000;
        BNN    = 6'b010000;
        PUM    = 6'b100000;
    } states;

    typedef enum logic [2:0] {
        GEMN_OP   = 3'b001;
        BNN_OP    = 3'b010;
        PUM_OP    = 3'b100;
    } operations;
     
    //==================================================
    // 2) Register file mapping
    // 0–7    : Control registers
    // 8      : Bypass register(from risc)
    // 9–15   : TEMP registers
    // 16–47  : R1 vector
    // 48–79  : R2 vector
    // 80–111 : RA vector
    //==================================================
    logic [31:0] RF_dim_a, RF_dim_b, RF_format, RF_tpum_mode;
    logic [31:0] RF_tpum_start, RF_base_pt_a, RF_base_pt_b, RF_base_pt_c;
    logic [31:0] RF_bypass_risc;
    logic [31:0] temp_regs [0:6];
    // packed array
    logic [31:0] r1_words   [0:31];
    logic [31:0] r2_words   [0:31];
    logic [31:0] ra_words   [0:31];

    logic [5:0] state , next_state;
    



    //==================================================
    // 1) APB protocol setup phase: latch address and write enable
    //==================================================
    logic [6:0] apb_RF_index;     // Word-aligned index (up to 128 registers)

    assign apb_access = apb.psel && apb.penable ;
    assign apb_setup_wr = apb_access &&  apb.pwrite ;
    assign apb_setup_rd = apb_access && !apb.pwrite ;

    


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        apb_RF_index <= 7'd0;
        end else if (apb.psel && !apb.penable) begin
        apb_RF_index <= apb.paddr[7:1];  // Uses [7:1] → shift by 2 and drops bit 0 (APB must align to 4B)
        end
    end

    //==================================================
    // 3) Register write operation
    //==================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RF_dim_a <= 0; RF_dim_b <= 0; RF_format <= 0; RF_tpum_mode <= 0;
            RF_tpum_start <= 0; RF_base_pt_a <= 0; RF_base_pt_b <= 0; RF_base_pt_c <= 0;RF_bypass_risc <=0;
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
                7'd0: RF_dim_a       <= apb.pwdata;
                7'd1: RF_dim_b       <= apb.pwdata;
                7'd2: RF_format      <= apb.pwdata;
                7'd3: RF_tpum_mode   <= apb.pwdata;
                7'd4: RF_tpum_start  <= apb.pwdata;
                7'd5: RF_base_pt_a   <= apb.pwdata;
                7'd6: RF_base_pt_b   <= apb.pwdata;
                7'd7: RF_base_pt_c   <= apb.pwdata;
                7'd8: RF_bypass_risc <= apb.pwdata;
                default: begin
                if (apb_RF_index >= 9  && apb_RF_index <= 15)
                    temp_regs[apb_RF_index - 9] <= apb.pwdata;
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
    always_comb begin
        read_data = 32'd0;
        
        if (apb_setup_rd) begin
            case (apb_RF_index)
                7'd0: read_data = RF_dim_a;
                7'd1: read_data = RF_dim_b;
                7'd2: read_data = RF_format;
                7'd3: read_data = RF_tpum_mode;
                7'd4: read_data = RF_tpum_start;
                7'd5: read_data = RF_base_pt_a;
                7'd6: read_data = RF_base_pt_b;
                7'd7: read_data = RF_base_pt_c;
                7'd8: read_data = RF_bypass_risc;
                default: begin
                if (apb_RF_index >= 9  && apb_RF_index <= 15)
                    read_data = temp_regs[apb_RF_index - 9];
                else if (apb_RF_index >= 16 && apb_RF_index <= 47)
                    read_data = r1_words[apb_RF_index - 16];
                else if (apb_RF_index >= 48 && apb_RF_index <= 79)
                    read_data = r2_words[apb_RF_index - 48];
                else if (apb_RF_index >= 80 && apb_RF_index <= 111)
                    read_data = ra_words[apb_RF_index - 80];
                end else begin
                    read_data = 32b'x;
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
    
    always @(*) begin
        case (state)
            IDLE: begin
                next_state = IDLE;
                //TODO: turn off all logic parts
                //if (start) begin
                //    next_state = INITR1; 
                //end
            end

            INITR1: begin
                next_state = INITR1;

                //if (xbox_read_ready) begin // depends on the XBOX protocol
                //    next_state = INITR2;
                //end 
                
            end

            INITR2: begin
                next_state = INITR2;

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


    always @(*) begin

        case (state)
            IDLE: begin
                //TODO: turn off all logic parts
            end

            INITR1: begin
                //if (xbox_read_ready) begin
                //    reg_r1_read_enable = 1;
                //    next_RF_curr_pt_a = RF_base_pt_a;
                //    //next_reg_r1 = XBOX[RF_base_pt_a];
                //end 
                
            end

            INITR2: begin
                //if (xbox_read_ready) begin
                //    reg_r2_read_enable = 1;
                //    next_RF_curr_pt_b = RF_base_pt_b;
                //    //next_reg_r2 = XBOX[RF_base_pt_b];
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