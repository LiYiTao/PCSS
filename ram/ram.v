module fifo_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
) (
    input  clk,
    input  wr_en,
    input  rd_en,
    input  [DATA_WIDTH-1:0] wr_data,
    input  [ADDR_WIDTH-1:0] wr_addr,
    input  [ADDR_WIDTH-1:0] rd_addr,
    output [DATA_WIDTH-1:0] rd_data
);
    reg [DATA_WIDTH-1:0] memory_rd_data;

    (* ram_style="distributed" *) reg [DATA_WIDTH-1:0] queue [2**ADDR_WIDTH-1:0];

always @(posedge clk) begin
    if (wr_en) begin
        queue[wr_addr] <= wr_data;
    end
    if (rd_en) begin
        memory_rd_data <= queue[rd_addr];
    end
end

assign rd_data = memory_rd_data;

endmodule


module flit_buffer #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
) (
    input  clk,
    input  rst_n,
    input  [DATA_WIDTH-1:0] in,
    output [DATA_WIDTH-1:0] out,
    input  wr_en,
    input  rd_en,
    output buffer_not_empty
);

reg  [ADDR_WIDTH-1:0] depth;
reg  [ADDR_WIDTH-1:0] rd_ptr;
reg  [ADDR_WIDTH-1:0] wr_ptr;

fifo_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
)
the_queue
(
    .clk(clk),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .wr_addr(wr_ptr),
    .wr_data(in),
    .rd_addr(rd_ptr),
    .rd_data(out)
);

assign buffer_not_empty = depth > 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= {ADDR_WIDTH{1'b0}};
        wr_ptr <= {ADDR_WIDTH{1'b0}};
        depth <= {ADDR_WIDTH{1'b0}};
    end
    else begin
        if (wr_en) wr_ptr <= wr_ptr + 1'b1;
        if (rd_en) rd_ptr <= rd_ptr + 1'b1;
        if (wr_en & ~rd_en) depth <= depth + 1'b1;
        else if (~wr_en & rd_en) depth <= depth - 1'b1;
    end
end

`ifdef debug

    always @(posedge clk) begin
        if(rst_n) begin
            if (wr_en && (depth == {ADDR_WIDTH{1'b1}}) && !rd_en)
                $display("%t: ERROR: Attempt to write to full FIFO: %m",$time);
            if (rd_en && (depth == {ADDR_WIDTH{1'b0}}) && !wr_en)
                $display("%t: ERROR: Attempt to read an empty FIFO: %m",$time);
        end
    end

`endif
    
endmodule

module data_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
) (
    input  clk,
    input  rst_n,
    input  [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout,
    input  wr_en,
    input  rd_en,
    output almost_full,
    output empty
);

reg  [ADDR_WIDTH-1:0] depth;
reg  [ADDR_WIDTH-1:0] rd_ptr;
reg  [ADDR_WIDTH-1:0] wr_ptr;

`ifdef FPGA
fifo_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
)
the_queue
(
    .clk(clk),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .wr_addr(wr_ptr),
    .wr_data(din),
    .rd_addr(rd_ptr),
    .rd_data(dout)
);
`endif 

`ifdef ASIC
S55DRAM_W64D1042 the_queue(
    QA    (  ),
    QB    (dout  ),
	CLKA  (clk ),
	CLKB  (clk ),
	CENA  (1'b1),
	CENB  (1'b1),
	WENA  (wr_en),
	WENB  (~rd_en),
	AA    (wr_ptr),
	AB    (rd_ptr),
	DA    (din  ),
	DB    (  )
);
`endif 

assign almost_full = depth >= {ADDR_WIDTH{1'b1}} - 1'b1;
assign empty = depth == 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= {ADDR_WIDTH{1'b0}};
        wr_ptr <= {ADDR_WIDTH{1'b0}};
        depth <= {ADDR_WIDTH{1'b0}};
    end
    else begin
        if (wr_en) wr_ptr <= wr_ptr + 1'b1;
        if (rd_en) rd_ptr <= rd_ptr + 1'b1;
        if (wr_en & ~rd_en) depth <= depth + 1'b1;
        else if (~wr_en & rd_en) depth <= depth - 1'b1;
    end
end

`ifdef debug

    always @(posedge clk) begin
        if(rst_n) begin
            if (wr_en && (depth == {ADDR_WIDTH{1'b1}}) && !rd_en)
                $display("%t: ERROR: Attempt to write to full FIFO: %m",$time);
            if (rd_en && (depth == {ADDR_WIDTH{1'b0}}) && !wr_en)
                $display("%t: ERROR: Attempt to read an empty FIFO: %m",$time);
        end
    end

`endif

endmodule