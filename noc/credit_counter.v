module credit_counter #(
    parameter P = 7,
    parameter B = 4
) (
    // system signal
    input  clk,
    input  rst_n,
    // credit
    input  [P-1:0] credit_in_all,
    output [P-1:0] credit_out_all,
    input  [P-1:0] flit_rel_all,
    // req
    output [P-1:0] outport_available_all,
    // ack
    input  [P*P-1:0] grant_outport_all
);

reg  [B-1:0] credit_counter_reg [P-1:0];
wire [P-1:0] increase;
wire [P-1:0] decrease;

// credit out (inport)
assign credit_out_all = flit_rel_all;

// credit counter (outport)
assign increase = credit_in_all;

genvar i;
generate

    for (i=0; i<P; i=i+1) begin
        
        assign decrease[i] = |grant_outport_all[(i+1)*P-1:i*P];
        assign outport_available_all[i] = credit_counter_reg[i] > 0;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                credit_counter_reg[i] <= {B{1'b1}};
            end
            else if (increase[i] && ~decrease[i]) begin
                credit_counter_reg[i] <= credit_counter_reg[i] + 1'b1;
            end
            else if (~increase[i] && decrease[i]) begin
                credit_counter_reg[i] <= credit_counter_reg[i] - 1'b1;
            end
        end

        `ifdef debug

            always @(posedge clk) begin
                if (rst_n) begin
                    if ((credit_counter_reg[i] == {B{1'b0}}) && ~increase[i] && decrease[i]) begin
                        $display("%t: ERROR: Attempt to send flit to full outport[%d]: %m",$time,i);
                    end
                    if ((credit_counter_reg[i] == {B{1'b1}}) && increase[i] && ~decrease[i]) begin
                        $display("%t: ERROR: unexpected credit recived for empty outport[%d]: %m",$time,i);
                    end
                end
            end

        `endif

    end

endgenerate

endmodule