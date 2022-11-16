module route_engine #(
    parameter P = 7,
    parameter XW = 4,
    parameter YW = 4,
    parameter TOPOLOGY = "HIER"
) (
    // current node
    input  current_r2, // current is r2
    input  [P-2:0] current_r1,
    input  [P-1:0] input_port,
    // dest node
    input  [XW-1:0] delta_x,
    input  [YW-1:0] delta_y,
    output reg [XW-1:0] delta_x_next,
    output reg [YW-1:0] delta_y_next,
    input  [P-2:0] dest_r1, // to node
    input  [P-2:0] dest_r2, // to r1
    output reg [P-1:0] dest_port
);
// TODO
localparam P0 = {{(P-1){1'b0}}, 1'b1};
localparam L = 5'b00001;
localparam E = 5'b00010;
localparam N = 5'b00100;
localparam W = 5'b01000;
localparam S = 5'b10000;

wire [P-2:0] delta_r1;

assign delta_r1 = dest_r2 ^ current_r1;

generate
    
    if (TOPOLOGY == "MESH") begin : MESH
        always @(*) begin
            delta_x_next = delta_x;
            delta_y_next = delta_y;
            if (delta_x[XW-2:0] == 0) begin
                if (delta_y[YW-2:0] == 0) begin
                    dest_port = L;
                end
                else if (!delta_y[YW-1]) begin // delta_y > 0
                    dest_port = N;
                    delta_y_next = delta_y + 1'b1;
                end
                else begin
                    dest_port = S;
                    delta_y_next = delta_y - 1'b1;
                end
            end
            else begin
                if (!delta_x[XW-1]) begin // delta_x > 0
                    dest_port = E;
                    delta_x_next = delta_x + 1'b1;
                end
                else begin
                    dest_port = W;
                    delta_x_next = delta_x - 1'b1;
                end
            end
        end
    end
    else begin : HIER
        always @(*) begin
            if ((delta_x[XW-2:0] == 0) && (delta_y[YW-2:0] == 0)) begin
                if (current_r2) begin // current node is R2
                    dest_port = {dest_r2, 1'b0};
                end
                else if ((input_port == P0) || (delta_r1 == 0)) begin // current node is R1
                    dest_port = {dest_r1, 1'b0};
                end
                else begin
                    dest_port = P0;
                end
            end
            else begin
                dest_port = P0;
            end
        end    
    end

endgenerate

endmodule