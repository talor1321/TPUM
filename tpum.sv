module TPUM (
    
);

    logic [31:0] reg_r1 ,next_reg_r1;
    logic [31:0] reg_r2 ,next_reg_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_r1 <= 0;
        end if (reg_r1_read_enable) begin 
            reg_r1 <= next_reg_r1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_r2<= 0;
        end if (reg_r2_read_enable) begin 
            reg_r2 <= next_reg_r2;
        end
    end




endmodule
