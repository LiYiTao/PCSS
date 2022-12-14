module pcss_inf #(
    parameter DATA_WIDTH = 64,
    parameter CHIPDATA_WIDTH = 16,
    parameter FIFO_DEPTH = 11
) (
    // system signal
    input  clk,
    input  rst_n,
    // AXI-stream send data
    input  [DATA_WIDTH-1:0]     S_AXIS_send_tdata,
    input                       S_AXIS_send_tvalid,
    input                       S_AXIS_send_tlast,
    input  [DATA_WIDTH/8-1:0]   S_AXIS_send_tkeep,
    output                      S_AXIS_send_tready,
    // AXI-stream recv data
    output [DATA_WIDTH-1:0]     M_AXIS_recv_tdata,
    output                      M_AXIS_recv_tvalid,
    output                      M_AXIS_recv_tlast,
    output [DATA_WIDTH/8-1:0]   M_AXIS_recv_tkeep,
    input                       M_AXIS_recv_tready,
    // signal with chip
    output                      tik,
    output [CHIPDATA_WIDTH-1:0] recv_data_in_E,
    output                      recv_data_valid_E,
    output                      recv_data_par_E,
    input                       recv_data_ready_E,
    input                       recv_data_err_E,
    input  [CHIPDATA_WIDTH-1:0] send_data_out_E,
    input                       send_data_valid_E,
    input                       send_data_par_E,
    output                      send_data_ready_E,
    output                      send_data_err_E
); // pcss_inf

wire tik_end;

fpga_send #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHIPDATA_WIDTH(CHIPDATA_WIDTH)
)
the_send
(
    .clk(clk),
    .rst_n(rst_n),
    // AXI-stream send data
    .dma_tdata(S_AXIS_send_tdata),
    .dma_tvalid(S_AXIS_send_tvalid),
    .dma_tready(S_AXIS_send_tready),
    // signal with chip
    .tik(tik),
    .recv_data_in_E(recv_data_in_E),
    .recv_data_valid_E(recv_data_valid_E),
    .recv_data_par_E(recv_data_par_E),
    .recv_data_ready_E(recv_data_ready_E),
    .recv_data_err_E(recv_data_err_E),
    // close tcp
    .tik_end(tik_end)
);

fpga_recv #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHIPDATA_WIDTH(CHIPDATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
)
the_recv
(
    .clk(clk),
    .rst_n(rst_n),
    .tik(tik),
    // AXI-stream recv data
    .dma_tdata(M_AXIS_recv_tdata),
    .dma_tvalid(M_AXIS_recv_tvalid),
    .dma_tlast(M_AXIS_recv_tlast),
    .dma_tkeep(M_AXIS_recv_tkeep),
    .dma_tready(M_AXIS_recv_tready),
    // signal with chip
    .send_data_out_E(send_data_out_E),
    .send_data_valid_E(send_data_valid_E),
    .send_data_par_E(send_data_par_E),
    .send_data_ready_E(send_data_ready_E),
    .send_data_err_E(send_data_err_E),
    // close tcp
    .tik_end(tik_end)
);

endmodule

module fpga_send #(
    parameter DATA_WIDTH = 64,
    parameter CHIPDATA_WIDTH = 16,
    parameter TIK_LEN = 32,
    parameter TIK_CNT = 32
) (
    // system signal
    input  clk,
    input  rst_n,
    // AXI-stream send data
    input  [DATA_WIDTH-1:0]     dma_tdata,
    input                       dma_tvalid,
    output                      dma_tready,
    // signal with chip
    output                      tik,
    output [CHIPDATA_WIDTH-1:0] recv_data_in_E,
    output                      recv_data_valid_E,
    output                      recv_data_par_E,
    input                       recv_data_ready_E,
    input                       recv_data_err_E,
    // close tcp
    output reg                  tik_end
);

// pkg type
localparam TIK = 3'b011;
// send
localparam SEND_IDLE  = 3'b000;
localparam SEND_DATA  = 3'b001;
localparam READY_WAIT = 3'b010;
localparam TIK_WAIT   = 3'b011;
localparam TIK_END    = 3'b100;

localparam CNT_FULL = 3'b100;

wire send_fifo_wr;
wire send_fifo_rd;
wire send_fifo_empty;
wire send_fifo_full;
wire [DATA_WIDTH-1:0] send_fifo_dout;
reg  tik_flg;
reg  [TIK_LEN-1:0] tik_len;
reg  [TIK_CNT-1:0] tik_cnt;

//--------------------------------------------------------------
//--------Send Data Logic-----------------
//--------------------------------------------------------------
reg  [2:0] send_cs;
reg  [2:0] send_ns;
reg  [2:0] send_cnt;
reg  send_data_ready_d;
reg  send_data_ready_2d;
reg  send_data_err_d;
reg  send_data_err_2d;
wire send_data_ready_h;
wire send_data_ready_l;
reg  [CHIPDATA_WIDTH-1:0] send_data_out;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_data_ready_d <= 1'b0;
        send_data_ready_2d <= 1'b0;
        send_data_err_d <= 1'b0;
        send_data_err_2d <= 1'b0;
    end
    else begin
        send_data_ready_d <= recv_data_ready_E;
        send_data_ready_2d <= send_data_ready_d;
        send_data_err_d <= recv_data_err_E;
        send_data_err_2d <= send_data_err_d;
    end
end

assign send_data_ready_h = send_data_ready_d & send_data_ready_2d;
assign send_data_ready_l = !send_data_ready_d & !send_data_ready_2d;
assign recv_data_in_E = send_data_out;
assign recv_data_valid_E = (send_cs == SEND_DATA) && (send_ns != TIK_WAIT); // TODO
assign recv_data_par_E = recv_data_valid_E ? ^send_data_out : 1'b0;


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_cs <= SEND_IDLE;
    end
    else begin
        send_cs <= send_ns;
    end
end

always @(*) begin
    case (send_cs)
        SEND_IDLE: begin
            if (!send_fifo_empty) send_ns = SEND_DATA;
            else send_ns = SEND_IDLE;
        end
        TIK_WAIT: begin
            if (~tik_flg) send_ns = SEND_IDLE;
            else send_ns = TIK_WAIT;
        end
        TIK_END: begin
            if (~tik_end) send_ns = SEND_IDLE;
            else send_ns = TIK_END;
        end
        SEND_DATA: begin
            if (send_fifo_dout[58:56] == TIK) begin
               if (send_fifo_dout[TIK_LEN]) send_ns = TIK_END;
               else send_ns = TIK_WAIT;
            end
            else if (send_data_ready_h) send_ns = READY_WAIT;
            else send_ns = SEND_DATA;
        end
        READY_WAIT: begin
            if (send_data_ready_l) begin
                if (send_cnt == CNT_FULL) send_ns = SEND_IDLE;
                else send_ns = SEND_DATA;
            end
            else send_ns = READY_WAIT;
        end
        default: send_ns = SEND_IDLE;
    endcase
end

// tik generate
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        tik_flg <= 1'b0;
        tik_end <= 1'b0;
        tik_len <= {TIK_LEN{1'b0}};
        tik_cnt <= {TIK_CNT{1'b0}};
    end
    else begin
        if (~tik_flg && (send_cs == SEND_DATA) && (send_ns == TIK_WAIT)) begin
            tik_flg <= 1'b1;
            tik_len <= send_fifo_dout[TIK_LEN-1:0];
        end
        else if (~tik_flg && (send_cs == SEND_DATA) && (send_ns == TIK_END)) begin
            tik_end <= 1'b1;
            tik_len <= send_fifo_dout[TIK_LEN-1:0];
        end
        else if (tik_flg && (tik_cnt >= tik_len)) begin
            tik_flg <= 1'b0;
            tik_len <= {TIK_LEN{1'b0}};
        end
        else if (tik_end && (tik_cnt >= tik_len)) begin
            tik_end <= 1'b0;
            tik_len <= {TIK_LEN{1'b0}};
        end

        if (tik_flg | tik_end) begin
            tik_cnt <= tik_cnt + 1'b1;
        end
        else begin
            tik_cnt <= {TIK_CNT{1'b0}};
        end
    end
end
assign tik = tik_flg;

// send data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_cnt <= 3'b0;
    end
    else if ((send_cs == SEND_DATA) && (send_ns == READY_WAIT) && !send_data_err_2d) begin
        send_cnt <= send_cnt + 3'b1;
    end
    else if ((send_cs == READY_WAIT) && (send_ns == SEND_IDLE)) begin
        send_cnt <= 3'b0;
    end
end

always @(*) begin
    case (send_cnt)
        3'b000:
            send_data_out = send_fifo_dout[63:48];
        3'b001:
            send_data_out = send_fifo_dout[47:32];
        3'b010:
            send_data_out = send_fifo_dout[31:16];
        3'b011:
            send_data_out = send_fifo_dout[15:0];
        default:
            send_data_out = {CHIPDATA_WIDTH{1'b0}};
    endcase
end

assign send_fifo_rd = (send_cs == SEND_IDLE) && (send_ns == SEND_DATA);
assign send_fifo_wr = dma_tvalid & dma_tready;
assign dma_tready = ~send_fifo_full;

// fifo (width 64)
fifo_generator_0 send_fifo // TODO
(
    .clk    (clk            ),
    .rst    (~rst_n         ),
    .wr_en  (send_fifo_wr   ),
    .din    (dma_tdata      ),
    .full   (send_fifo_full ),
    .rd_en  (send_fifo_rd   ),
    .dout   (send_fifo_dout ),
    .empty  (send_fifo_empty)
);

endmodule // fpga_send

module fpga_recv #(
    parameter DATA_WIDTH = 64,
    parameter CHIPDATA_WIDTH = 16,
    parameter FIFO_DEPTH = 11
) (
    // system signal
    input  clk,
    input  rst_n,
    // ctrl
    input  tik,
    // AXI-stream recv data
    output [DATA_WIDTH-1:0]     dma_tdata,
    output reg                  dma_tvalid,
    output                      dma_tlast,
    output [DATA_WIDTH/8-1:0]   dma_tkeep,
    input                       dma_tready,
    // signal with chip
    input  [CHIPDATA_WIDTH-1:0] send_data_out_E,
    input                       send_data_valid_E,
    input                       send_data_par_E,
    output                      send_data_ready_E,
    output                      send_data_err_E,
    // tcp close
    input                       tik_end
);

// pkg type
localparam TIK = 3'b011;
// recv
localparam RECV_IDLE      = 3'b000;
localparam RECV_DATA_SAMP = 3'b001;
localparam VALID_WAIT     = 3'b010;
localparam TIK_WAIT       = 3'b011;
localparam TIK_END        = 3'b100;

localparam CNT_FULL = 3'b100;
localparam BURST_NUM = 16; // TODO

reg  dma_valid_ready; // hold previous read data
reg  dma_burst;
wire recv_fifo_wr;
wire recv_fifo_rd;
wire recv_fifo_empty;
wire recv_fifo_full;
wire [DATA_WIDTH-1:0] recv_fifo_dout;
reg  [DATA_WIDTH-1:0] recv_fifo_din;
reg  [FIFO_DEPTH-1:0] recv_fifo_cnt;
reg  tik_dly;
reg  tik_end_dly;
reg  tik_neg_hold;
reg  tik_end_hold;
wire tik_neg_wr;
wire tik_end_wr;

// dma logic
assign dma_tkeep = dma_tvalid ? {(DATA_WIDTH/8){1'b1}} : {(DATA_WIDTH/8){1'b0}};
assign dma_tdata = recv_fifo_dout;
assign dma_tlast = dma_tvalid & recv_fifo_empty; // TODO

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        dma_tvalid <= 1'b0;
    end
    else begin
        dma_tvalid <= recv_fifo_rd | (dma_valid_ready & dma_tready);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        dma_valid_ready <= 1'b0;
    end
    else if (dma_tvalid & ~dma_tready) begin
        dma_valid_ready <= 1'b1;
    end
    else if (dma_tready) begin
        dma_valid_ready <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        dma_burst <= 1'b0;
    end
    else if ((recv_fifo_cnt >= BURST_NUM) | tik_neg_wr | tik_end_wr) begin
        dma_burst <= 1'b1;
    end
    else if (recv_fifo_empty) begin
        dma_burst <= 1'b0;
    end
end

assign recv_fifo_rd = dma_tready && (!dma_valid_ready) && dma_burst && (!recv_fifo_empty);

//--------------------------------------------------------------
//--------Receive Data Logic-----------------
//--------------------------------------------------------------
reg  [2:0] recv_cs;
reg  [2:0] recv_ns;
reg  [2:0] recv_cnt; // 16 bit data width, receive 64 bits at most;
reg  recv_data_valid_d;
reg  recv_data_valid_2d;
reg  recv_data_par_d;
reg  recv_data_par_2d;
reg  [CHIPDATA_WIDTH-1:0] recv_data_in_d;
reg  [CHIPDATA_WIDTH-1:0] recv_data_in_2d;
wire recv_data_valid_h;
wire recv_data_valid_l;
wire recv_data_par_err;
reg  recv_data_ready;
reg  recv_data_err;

// tik dly
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        tik_dly <= 1'b0;
        tik_neg_hold <= 1'b0;
    end
    else begin
        tik_dly <= tik;
        if (tik_dly && !tik) begin
            tik_neg_hold <= 1'b1;
        end
        else if ((recv_cs == TIK_WAIT) && (recv_ns == RECV_IDLE)) begin
            tik_neg_hold <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        tik_end_dly <= 1'b0;
        tik_end_hold <= 1'b0;
    end
    else begin
        tik_end_dly <= tik_end;
        if (tik_end_dly && !tik_end) begin
            tik_end_hold <= 1'b1;
        end
        else if ((recv_cs == TIK_END) && (recv_ns == RECV_IDLE)) begin
            tik_end_hold <= 1'b0;
        end
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_data_valid_d <= 1'b0;
        recv_data_valid_2d <= 1'b0;
        recv_data_par_d <= 1'b0;
        recv_data_par_2d <= 1'b0;
        recv_data_in_d <= {CHIPDATA_WIDTH{1'b0}};
        recv_data_in_2d <= {CHIPDATA_WIDTH{1'b0}};
    end
    else begin
        recv_data_valid_d <= send_data_valid_E;
        recv_data_valid_2d <= recv_data_valid_d;
        recv_data_par_d <= send_data_par_E;
        recv_data_par_2d <= recv_data_par_d;
        recv_data_in_d <= send_data_out_E;
        recv_data_in_2d <= recv_data_in_d;
    end
end

assign recv_data_valid_h = recv_data_valid_d & recv_data_valid_2d;
assign recv_data_valid_l = !recv_data_valid_d & !recv_data_valid_2d;
assign recv_data_par_err = recv_data_valid_h ? (^recv_data_in_2d != recv_data_par_2d) : 1'b0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_cs <= RECV_IDLE;
    end
    else begin
        recv_cs <= recv_ns;
    end
end

always @(*) begin
    case (recv_cs)
        RECV_IDLE: begin
            if (tik_end_hold) recv_ns = TIK_END;
            else if (tik_neg_hold) recv_ns = TIK_WAIT;
            else if (recv_data_valid_h) recv_ns = RECV_DATA_SAMP;
            else recv_ns = RECV_IDLE;
        end
        TIK_WAIT: begin
            if (!recv_fifo_full) recv_ns = RECV_IDLE;
            else recv_ns = TIK_WAIT;
        end
        TIK_END: begin
            if (!recv_fifo_full) recv_ns = RECV_IDLE;
            else recv_ns = TIK_END;
        end
        RECV_DATA_SAMP: begin
            if (recv_data_valid_l) begin
                if (recv_cnt == CNT_FULL) recv_ns = RECV_IDLE;
                else recv_ns = VALID_WAIT;
            end
            else recv_ns = RECV_DATA_SAMP;
        end
        VALID_WAIT: begin
            if (recv_data_valid_h) recv_ns = RECV_DATA_SAMP;
            else recv_ns = VALID_WAIT;
        end
        default: begin
           recv_ns = RECV_IDLE; 
        end
    endcase
end

// recv ready
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_data_ready <= 1'b0;
        recv_data_err <= 1'b0;
    end
    else if ((recv_cs == RECV_IDLE) && (recv_ns == RECV_DATA_SAMP)) begin
        recv_data_ready <= !recv_fifo_full;
        recv_data_err <= recv_data_par_err;
    end
    else if (recv_cs == RECV_DATA_SAMP) begin
        if (recv_ns != RECV_DATA_SAMP) begin
            recv_data_ready <= 1'b0;
            recv_data_err <= 1'b0;
        end
        else if ((recv_ns == RECV_DATA_SAMP) && !recv_fifo_full) begin
            recv_data_ready <= 1'b1;
            recv_data_err <= recv_data_par_err;
        end
    end
    else if ((recv_cs == VALID_WAIT) && (recv_ns == RECV_DATA_SAMP)) begin
        recv_data_ready <= 1'b1;
        recv_data_err <= recv_data_par_err;
    end
    else if (recv_ns == RECV_IDLE) begin
        recv_data_ready <= 1'b0;
        recv_data_err <= 1'b0;
    end
end
assign send_data_ready_E = recv_data_ready;
assign send_data_err_E = recv_data_err;

// recv data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_cnt <= 3'b0;
        recv_fifo_din <= {DATA_WIDTH{1'b0}};
    end
    else if ((recv_cs != RECV_DATA_SAMP) && (recv_ns == RECV_DATA_SAMP) && !recv_data_par_err) begin
        recv_cnt <= recv_cnt + 3'b1;
        case (recv_cnt)
            // TODO
            3'b000: begin
                recv_fifo_din[63:48] <= recv_data_in_2d;
            end
            3'b001: begin
                recv_fifo_din[47:32] <= recv_data_in_2d;
            end
            3'b010: begin
                recv_fifo_din[31:16] <= recv_data_in_2d;
            end
            3'b011: begin
                recv_fifo_din[15:0] <= recv_data_in_2d;
            end
        endcase
    end
    else if (recv_cs == RECV_IDLE) begin
        recv_cnt <= 3'b0;
        if (recv_ns == TIK_WAIT) recv_fifo_din <= {5'b0, TIK, 56'b0};
        else if (recv_ns == TIK_END) recv_fifo_din <= {64'hffff_ffff_ffff_ffff};
    end
end
assign tik_neg_wr = (recv_cs == TIK_WAIT) && (recv_ns == RECV_IDLE);
assign tik_end_wr = (recv_cs == TIK_END) && (recv_ns == RECV_IDLE);
assign recv_fifo_wr = ((recv_cs == RECV_DATA_SAMP) && (recv_ns == RECV_IDLE)) || tik_neg_wr || tik_end_wr;
// fifo (width 64)
fifo_generator_0 recv_fifo // TODO
(
    .clk    (clk            ),
    .rst    (~rst_n         ),
    .wr_en  (recv_fifo_wr   ),
    .din    (recv_fifo_din  ),
    .full   (recv_fifo_full ),
    .rd_en  (recv_fifo_rd   ),
    .dout   (recv_fifo_dout ),
    .empty  (recv_fifo_empty)
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        recv_fifo_cnt <= {FIFO_DEPTH{1'b0}};
    end
    else begin
        if (recv_fifo_wr & ~recv_fifo_rd) recv_fifo_cnt <= recv_fifo_cnt + 1'b1;
        else if (~recv_fifo_wr & recv_fifo_rd) recv_fifo_cnt <= recv_fifo_cnt - 1'b1;
    end
end

endmodule // fpga_recv
