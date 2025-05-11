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
    logic [31:0] reg_a , reg_b;
    
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

                if (xbox_read_ready) begin
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
        case (state)
            IDLE: begin
                //TODO: turn off all logic parts
            end

            INITR1: begin
                reg_r1_read_enable = 0;
                reg_r2_read_enable = 0;

                if (xbox_read_ready) begin
                    reg_r1_read_enable = 1;
                end 
                
            end

            INITR2: begin
                reg_r1_read_enable = 0;
                reg_r2_read_enable = 0;

                if (xbox_read_ready) begin
                    reg_r2_read_enable = 1;

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