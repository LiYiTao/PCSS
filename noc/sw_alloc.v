module sw_alloc #(
    parameter P = 7
) (
    // system signals
    input clk,
    input rst_n,
    // req
    input [P*P-1:0] dest_port_req_all,
    input [P-1:0] outport_available_all,
    // ack
    output [P*P-1:0] grant_dest_port_all,
    output [P*P-1:0] grant_outport_all // each outport grant inport
);

wire [P*P-1:0] dest_port_req_mask;
wire [P-1:0] outport_req [P-1:0];
wire [P-1:0] outport_grant [P-1:0];

genvar i,j;
generate
    for (i=0; i<P; i=i+1) begin : inport_loop
        assign dest_port_req_mask[(i+1)*P-1:i*P] = dest_port_req_all[(i+1)*P-1:i*P] & outport_available_all;
    end

    for (j=0; j<P; j=j+1) begin : outport_loop

        assign  grant_outport_all[(j+1)*P-1:j*P] = outport_grant[j];
        
        for (i=0; i<P; i=i+1) begin : inport_loop
            assign outport_req[j][i] = dest_port_req_mask[i*P+j];
            assign grant_dest_port_all[i*P+j] = outport_grant[j][i];
        end

        round_arbiter #(
            .ARBITER_WIDTH(P)
        )
        outport_arbiter
        (
            .clk(clk),
            .rst_n(rst_n),
            .request(outport_req[j]),
            .grant(outport_grant[j])
        );
    end
endgenerate

endmodule

/*****************************************
		
		round robin arbiter
 
******************************************/

module round_arbiter #(
    parameter ARBITER_WIDTH = 7
) (
    input  clk,
    input  rst_n,
    input  [ARBITER_WIDTH-1:0] request,
    output reg [ARBITER_WIDTH-1:0] grant
);
// TODO port is not 7
generate

    if (ARBITER_WIDTH == 7) begin : arbiter_7

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                grant <= 7'b0000000;
            end
            else case(grant)
                7'b0000000:
                    if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else grant <= 7'b0000000;
                7'b0000001:
                    if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else grant <= 7'b0000000;
                7'b0000010:
                    if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else grant <= 7'b0000000;
                7'b0000100:
                    if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else grant <= 7'b0000000;
                7'b0001000:
                    if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else grant <= 7'b0000000;
                7'b0010000:
                    if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else grant <= 7'b0000000;
                7'b0100000:
                    if (request[6]) grant <= 7'b1000000;
                    else if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else grant <= 7'b0000000;
                7'b1000000:
                    if (request[0]) grant <= 7'b0000001;
                    else if (request[1]) grant <= 7'b0000010;
                    else if (request[2]) grant <= 7'b0000100;
                    else if (request[3]) grant <= 7'b0001000;
                    else if (request[4]) grant <= 7'b0010000;
                    else if (request[5]) grant <= 7'b0100000;
                    else if (request[6]) grant <= 7'b1000000;
                    else grant <= 7'b0000000;
                default:
                    grant <= 7'b0000000;
            endcase
        end

    end
    else begin : arbiter_5
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                grant <= 5'b00000;
            end
            else case(grant)
                5'b00000:
                    if (request[0]) grant <= 5'b00001;
                    else if (request[1]) grant <= 5'b00010;
                    else if (request[2]) grant <= 5'b00100;
                    else if (request[3]) grant <= 5'b01000;
                    else if (request[4]) grant <= 5'b10000;
                    else grant <= 5'b00000;
                5'b00001:
                    if (request[1]) grant <= 5'b00010;
                    else if (request[2]) grant <= 5'b00100;
                    else if (request[3]) grant <= 5'b01000;
                    else if (request[4]) grant <= 5'b10000;
                    else if (request[0]) grant <= 5'b00001;
                    else grant <= 5'b00000;
                5'b00010:
                    if (request[2]) grant <= 5'b00100;
                    else if (request[3]) grant <= 5'b01000;
                    else if (request[4]) grant <= 5'b10000;
                    else if (request[0]) grant <= 5'b00001;
                    else if (request[1]) grant <= 5'b00010;
                    else grant <= 5'b00000;
                5'b00100:
                    if (request[3]) grant <= 5'b01000;
                    else if (request[4]) grant <= 5'b10000;
                    else if (request[0]) grant <= 5'b00001;
                    else if (request[1]) grant <= 5'b00010;
                    else if (request[2]) grant <= 5'b00100;
                    else grant <= 5'b00000;
                5'b01000:
                    if (request[4]) grant <= 5'b10000;
                    else if (request[0]) grant <= 5'b00001;
                    else if (request[1]) grant <= 5'b00010;
                    else if (request[2]) grant <= 5'b00100;
                    else if (request[3]) grant <= 5'b01000;
                    else grant <= 5'b00000;
                5'b10000:
                    if (request[0]) grant <= 5'b00001;
                    else if (request[1]) grant <= 5'b00010;
                    else if (request[2]) grant <= 5'b00100;
                    else if (request[3]) grant <= 5'b01000;
                    else if (request[4]) grant <= 5'b10000;
                    else grant <= 5'b00000;
                default:
                    grant <= 5'b00000;
            endcase
        end

    end
    
endgenerate

`ifdef debug

    always @(posedge clk) begin
        if(rst_n) begin
            if ((ARBITER_WIDTH != 7) && (ARBITER_WIDTH != 5) )
                $display("%t: ERROR: Arbiter width is mismatched",$time);
        end
    end

`endif

endmodule
