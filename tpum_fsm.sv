module TPUM_FSM (
    // INPUTS
    input clk,
    input rst_n,
    input [1023:0] xbox_data, //pum_mem_rdata
    //input [16*8*5-1:0] apb_input, //APB_BUS.Slave apb

    // OUTPUTS
    output xbox_rd, //pum_mem_rd
    output xbox_wr, //pum_mem_wr
    output [13:0] xbox_addr, //pum_mem_addr
    output [1023:0] xbox_data, //pum_mem_wdata
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
     
    
    logic [4:0] state , next_state;
    // R1 and R2 registers
    logic [1023:0] reg_r1 , reg_r2;
    logic [1023:0] next_reg_r1 , next_reg_r2;
    logic [1023:0] next_reg_ra , next_reg_ra;
    
    // RF registers 
    logic [31:0] RF_dim_a; // [9:0] = vertical , [19:10] = horizontal(10 bits each)
    logic [31:0] RF_dim_b; // [9:0] = vertical , [19:10] = horizontal(10 bits each)
    logic [31:0] RF_format;
    logic [31:0] RF_tpum_mode;
    logic [31:0] RF_tpum_start;
    logic [31:0] RF_base_pt_a;
    logic [31:0] RF_base_pt_b;  
    logic [31:0] RF_base_pt_c;

    // Registers in the TPUM unit
    // registers for saving the address pointers
    logic [31:0] RF_curr_pt_a , next_RF_curr_pt_a;
    logic [31:0] RF_curr_pt_b , next_RF_curr_pt_b;
    logic [31:0] RF_curr_pt_c , next_RF_curr_pt_c;

    // APB
    assign rm_example_addr = apb.paddr[21:0];
    assign is_rm_example_reg_addr = apb.psel && rm_example_addr[21:21] == 1'b1;
    assign is_rm_example_mem_addr = apb.psel && rm_example_addr[21:21] != 1'b1;
    assign reg_idx = rm_example_addr[6:2];
    assign apb_setup_wr = apb.psel &&  apb.pwrite  ;
    assign apb_setup_rd = apb.psel && !apb.pwrite  ;
    assign apb_access = apb.psel && apb.penable ;
    assign apb_wr_reg = apb_setup_wr && is_rm_example_reg_addr && !ready ;
    assign regs_rd_access = apb_setup_rd && is_rm_example_reg_addr && !ready ;

    assign start = RF_tpum_start[0];
    assign op_mode = RF_tpum_mode[2:0];

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
                if (start) begin
                    next_state = INITR1; 
                end
            end

            INITR1: begin
                next_state = INITR1;

                if (xbox_read_ready) begin // depends on the XBOX protocol
                    next_state = INITR2;
                end 
                
            end

            INITR2: begin
                next_state = INITR2;

                if (xbox_read_ready) begin
                    case (op_mode) 
                        GEMM_OP: begin
                            next_state = GEMM;
                        end
            
                        BNN_OP: begin
                            next_state = BNN;
                        end

                        PUM_OP: begin
                            next_state = PUM;
                        end
                    end  
                end
            end
            
            GEMN: begin
            
            end
            
            BNN: begin
            
            end

            PUM: begin
            
            end


    end


    always @(*) begin
        reg_r1_read_enable = 0;
        reg_r2_read_enable = 0;
        next_RF_curr_pt_a = RF_curr_pt_a;
        next_reg_r1 = reg_r1;
        reg_r1_read_enable = 0;
        reg_r2_read_enable = 0;
        next_RF_curr_pt_b = RF_curr_pt_b;
        next_reg_r2 = reg_r2;

        case (state)
            IDLE: begin
                //TODO: turn off all logic parts
            end

            INITR1: begin
                if (xbox_read_ready) begin
                    reg_r1_read_enable = 1;
                    next_RF_curr_pt_a = RF_base_pt_a;
                    //next_reg_r1 = XBOX[RF_base_pt_a];
                end 
                
            end

            INITR2: begin
                if (xbox_read_ready) begin
                    reg_r2_read_enable = 1;
                    next_RF_curr_pt_b = RF_base_pt_b;
                    //next_reg_r2 = XBOX[RF_base_pt_b];
                end
            end
            
            GEMN: begin
            
            end
            
            BNN: begin
            
            end

            PUM: begin
            
            end


    end


endmodule