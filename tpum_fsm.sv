module TPUM_FSM (
    // INPUTS
    input clk,
    input rst_n,
    input start, // pooling out of RX_*
    input [1:0] op_mode,
    input input_format,
    input xbox_read_ready, 
    input xbox_read_valid, 
    input xbox_write_isready, 
    input in2,

    // OUTPUTS
    output out1,
    output xbox_write_ready, 
    output reg_r1_read_enable, 
    output reg_r2_read_enable, 
    output out2
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
    
    // RX registers from XBOX
    logic [31:0] RX_vert_dim_a; 
    logic [31:0] RX_vert_dim_b;
    logic [31:0] RX_horz_dim_a;
    logic [31:0] RX_horz_dim_b;
    logic [31:0] RX_format;
    logic [31:0] RX_tpum_mode;
    logic [31:0] RX_tpum_start;
    logic [31:0] RX_base_pt_a;
    logic [31:0] RX_base_pt_b;  
    logic [31:0] RX_base_pt_c;

    // Registers in the TPUM unit
    // registers for saving the address pointers
    logic [31:0] RX_curr_pt_a , next_RX_curr_pt_a;
    logic [31:0] RX_curr_pt_b , next_RX_curr_pt_b;
    logic [31:0] RX_curr_pt_c , next_RX_curr_pt_c;


    assign start = RX_tpum_start[0];
    assign op_mode = RX_tpum_mode[2:0];

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
        next_RX_curr_pt_a = RX_curr_pt_a;
        next_reg_r1 = reg_r1;
        reg_r1_read_enable = 0;
        reg_r2_read_enable = 0;
        next_RX_curr_pt_b = RX_curr_pt_b;
        next_reg_r2 = reg_r2;

        case (state)
            IDLE: begin
                //TODO: turn off all logic parts
            end

            INITR1: begin
                if (xbox_read_ready) begin
                    reg_r1_read_enable = 1;
                    next_RX_curr_pt_a = RX_base_pt_a;
                    //next_reg_r1 = XBOX[RX_base_pt_a];
                end 
                
            end

            INITR2: begin
                if (xbox_read_ready) begin
                    reg_r2_read_enable = 1;
                    next_RX_curr_pt_b = RX_base_pt_b;
                    //next_reg_r2 = XBOX[RX_base_pt_b];
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