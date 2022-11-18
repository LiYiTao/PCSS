module chip_interface #(
    parameter FW = 64, // TODO
    parameter CONNECT = 2,
    parameter CHIPDATA_WIDTH = 16
) (
    // system signal
    input  clk,
    input  rst_n,
    // chip connection
    output data_in_wr,
    output [FW+log2(CONNECT)-1:0] data_in,
    input  data_out_wr,
    input  [FW+log2(CONNECT)-1:0] data_out,
    output send_fifo_full,
    input  [CONNECT-1:0] connect_available,
    // recv
    input  [CHIPDATA_WIDTH-1:0] recv_data_in,
    input  recv_data_valid,
    input  recv_data_par,
    output reg recv_data_ready,
    output reg recv_data_err,
    // send
    output reg [CHIPDATA_WIDTH-1:0] send_data_out,
    output send_data_valid,
    output send_data_par,
    input  send_data_ready,
    input  send_data_err
);
    
function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

// send & recv
localparam SEND_IDLE = 2'b00;
localparam SEND_DATA = 2'b01;
localparam READY_WAIT = 2'b10;

localparam RECV_IDLE = 2'b00;
localparam RECV_DATA_SAMP = 2'b01;
localparam VALID_WAIT = 2'b10;

// TODO send fifo depth
localparam SEND_FIFO_DEPTH = 10;
localparam CNT_FULL = 3'b100;

//--------------------------------------------------------------
//--------Receive Data Logic-----------------
//--------------------------------------------------------------
reg  [1:0] recv_cs;
reg  [1:0] recv_ns;
reg  [2:0] recv_cnt; // 16 bit data width, receive 64 bits at most;
reg  recv_data_valid_d;
reg  recv_data_valid_2d;
reg  recv_data_valid_3d;
reg  recv_data_par_d;
reg  recv_data_par_2d;
reg  [CHIPDATA_WIDTH-1:0] recv_data_in_d;
reg  [CHIPDATA_WIDTH-1:0] recv_data_in_2d;
wire recv_data_valid_h;
wire recv_data_valid_l;
wire recv_data_par_err;
wire recv_full;
wire [log2(CONNECT)-1:0] recv_index;
reg  [FW+log2(CONNECT)-1:0] data_in_temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_data_valid_d <= 1'b0;
        recv_data_valid_2d <= 1'b0;
        recv_data_valid_3d <= 1'b0;
        recv_data_par_d <= 1'b0;
        recv_data_par_2d <= 1'b0;
        recv_data_in_d <= {CHIPDATA_WIDTH{1'b0}};
        recv_data_in_2d <= {CHIPDATA_WIDTH{1'b0}};
    end
    else begin
        recv_data_valid_d <= recv_data_valid;
        recv_data_valid_2d <= recv_data_valid_d;
        recv_data_valid_3d <= recv_data_valid_2d;
        recv_data_par_d <= recv_data_par;
        recv_data_par_2d <= recv_data_par_d;
        recv_data_in_d <= recv_data_in;
        recv_data_in_2d <= recv_data_in_d;
    end
end

assign recv_data_valid_h = recv_data_valid_2d & recv_data_valid_3d;
assign recv_data_valid_l = !recv_data_valid_2d & !recv_data_valid_3d;
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
            if (recv_data_valid_h) recv_ns = RECV_DATA_SAMP;
            else recv_ns = RECV_IDLE;
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
assign recv_full = !connect_available[recv_index];
assign recv_index = recv_data_in_2d[CHIPDATA_WIDTH-1:CHIPDATA_WIDTH-log2(CONNECT)]; //TODO

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_data_ready <= 1'b0;
        recv_data_err <= 1'b0;
    end
    else if ((recv_cs == RECV_IDLE) && (recv_ns != RECV_IDLE)) begin
        recv_data_ready <= !recv_full;
        recv_data_err <= recv_data_par_err;
    end
    else if (recv_cs == RECV_DATA_SAMP) begin
        if (recv_ns != RECV_DATA_SAMP) begin
            recv_data_ready <= 1'b0;
            recv_data_err <= 1'b0;
        end
        else if ((recv_ns == RECV_DATA_SAMP) && !recv_full) begin
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

// recv data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        recv_cnt <= 3'b0;
        data_in_temp <= {(FW+log2(CONNECT)){1'b0}};
    end
    else if ((recv_cs != RECV_DATA_SAMP) && (recv_ns == RECV_DATA_SAMP) && !recv_data_par_err) begin
        recv_cnt <= recv_cnt + 3'b1;
        case (recv_cnt)
            // TODO
            3'b000: begin
                data_in_temp[63:48] <= recv_data_in_2d;
            end
            3'b001: begin
                data_in_temp[47:32] <= recv_data_in_2d;
            end
            3'b010: begin
                data_in_temp[31:16] <= recv_data_in_2d;
            end
            3'b011: begin
                data_in_temp[15:0] <= recv_data_in_2d;
            end
        endcase
    end
    else if (recv_cs == RECV_IDLE) begin
        recv_cnt <= 3'b0;
    end
end
assign data_in = data_in_temp;
assign data_in_wr = (recv_cs == RECV_DATA_SAMP) && (recv_ns == RECV_IDLE);

//--------------------------------------------------------------
//--------Send Data Logic-----------------
//--------------------------------------------------------------
reg  [1:0] send_cs;
reg  [1:0] send_ns;
reg  [2:0] send_cnt;
reg  send_data_ready_d;
reg  send_data_ready_2d;
reg  send_data_ready_3d;
reg  send_data_err_d;
reg  send_data_err_2d;
wire send_data_ready_h;
wire send_data_ready_l;
wire send_fifo_empty;
wire send_rd_en;
wire send_wr_en;
wire [FW+log2(CONNECT)-1:0] send_rd_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_data_ready_d <= 1'b0;
        send_data_ready_2d <= 1'b0;
        send_data_ready_3d <= 1'b0;
        send_data_err_d <= 1'b0;
        send_data_err_2d <= 1'b0;
    end
    else begin
        send_data_ready_d <= send_data_ready;
        send_data_ready_2d <= send_data_ready_d;
        send_data_ready_3d <= send_data_ready_2d;
        send_data_err_d <= send_data_err;
        send_data_err_2d <= send_data_err_d;
    end
end

assign send_data_ready_h = send_data_ready_2d & send_data_ready_3d;
assign send_data_ready_l = !send_data_ready_2d & !send_data_ready_3d;

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
        SEND_DATA: begin
            if (send_data_ready_h) send_ns = READY_WAIT;
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
            send_data_out = send_rd_data[63:48];
        3'b001:
            send_data_out = send_rd_data[47:32];
        3'b010:
            send_data_out = send_rd_data[31:16];
        3'b011:
            send_data_out = send_rd_data[15:0];
        default:
            send_data_out = {CHIPDATA_WIDTH{1'b0}};
    endcase
end

assign send_rd_en = (send_cs == SEND_IDLE) && (send_ns == SEND_DATA);
assign send_data_valid = send_cs == SEND_DATA;
assign send_data_par = send_data_valid ? ^send_data_out : 1'b0;

// send fifo
data_fifo #(
    .DATA_WIDTH(FW+log2(CONNECT)),
    .ADDR_WIDTH(SEND_FIFO_DEPTH)
)
send_fifo
(
    .clk(clk),
    .rst_n(rst_n),
    .din(data_out),
    .dout(send_rd_data),
    .wr_en(data_out_wr),
    .rd_en(send_rd_en),
    .almost_full(send_fifo_full),
    .empty(send_fifo_empty)
);

endmodule