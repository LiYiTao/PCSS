module pcss_top #(
    parameter FW = 59,
    parameter B = 4,
    parameter XW = 4,
    parameter YW = 4,
    parameter CONNECT = 2, // NX,NY
    parameter P_MESH = 5,
    parameter P_HIER = 7,
    parameter CHIPDATA_WIDTH = 16,
    parameter FTW = 3,  // flit type width
    parameter ATW = 3,  // address type width
    parameter CDW = 21, // config data width
    parameter CAW = 15, // config addres width
    parameter NNW = 9, // TODO neural number width
    parameter WW = 16, // weight width
    parameter WD = 6, // weight depth (8x8)
    parameter VW = 20, // Vm width
    parameter SW = 24, // spk width, (x,y,z)
    parameter CODE_WIDTH = 2, // spike code width
    parameter DST_WIDTH = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH = 4 // dst node depth
) (
    // System Sginals
    input  clk,
    input  rst_n,
    // ctrl
    input  tik,
    // East send/recv port
    input  [CHIPDATA_WIDTH-1:0] recv_data_in_E,
    input  recv_data_valid_E,
    input  recv_data_par_E,
    output recv_data_ready_E,
    output recv_data_err_E,
    output [CHIPDATA_WIDTH-1:0] send_data_out_E,
    output send_data_valid_E,
    output send_data_par_E,
    input  send_data_ready_E,
    input  send_data_err_E,
    // North port
    input  [CHIPDATA_WIDTH-1:0] recv_data_in_N,
    input  recv_data_valid_N,
    input  recv_data_par_N,
    output recv_data_ready_N,
    output recv_data_err_N,
    output [CHIPDATA_WIDTH-1:0] send_data_out_N,
    output send_data_valid_N,
    output send_data_par_N,
    input  send_data_ready_N,
    input  send_data_err_N,
    // West port
    input  [CHIPDATA_WIDTH-1:0] recv_data_in_W,
    input  recv_data_valid_W,
    input  recv_data_par_W,
    output recv_data_ready_W,
    output recv_data_err_W,
    output [CHIPDATA_WIDTH-1:0] send_data_out_W,
    output send_data_valid_W,
    output send_data_par_W,
    input  send_data_ready_W,
    input  send_data_err_W,
    // South port
    input  [CHIPDATA_WIDTH-1:0] recv_data_in_S,
    input  recv_data_valid_S,
    input  recv_data_par_S,
    output recv_data_ready_S,
    output recv_data_err_S,
    output [CHIPDATA_WIDTH-1:0] send_data_out_S,
    output send_data_valid_S,
    output send_data_par_S,
    input  send_data_ready_S,
    input  send_data_err_S
);

function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

wire  [FW*(P_MESH-1)-1:0] flit_in [CONNECT-1:0];
wire  [(P_MESH-1)-1:0] flit_in_wr [CONNECT-1:0];
wire  [FW*(P_MESH-1)-1:0] flit_out [CONNECT-1:0];
wire  [(P_MESH-1)-1:0] flit_out_wr [CONNECT-1:0];
wire  [(P_MESH-1)-1:0] credit_in [CONNECT-1:0];
wire  [(P_MESH-1)-1:0] credit_out [CONNECT-1:0];
wire  [FW*CONNECT-1:0] flit_in_noc [(P_MESH-1)-1:0];
wire  [CONNECT-1:0] flit_in_wr_noc [(P_MESH-1)-1:0];
wire  [FW*CONNECT-1:0] flit_out_noc [(P_MESH-1)-1:0];
wire  [CONNECT-1:0] flit_out_wr_noc [(P_MESH-1)-1:0];
wire  [CONNECT-1:0] credit_in_noc [(P_MESH-1)-1:0];
wire  [CONNECT-1:0] credit_out_noc [(P_MESH-1)-1:0];

wire  [(P_MESH-1)-1:0] data_in_wr;
wire  [FW+log2(CONNECT)-1:0] data_in [(P_MESH-1)-1:0];
wire  [(P_MESH-1)-1:0] data_out_wr;
wire  [FW+log2(CONNECT)-1:0] data_out [(P_MESH-1)-1:0];
wire  [(P_MESH-1)-1:0] send_fifo_full;
wire  [CONNECT-1:0] connect_available [(P_MESH-1)-1:0];

wire  [CHIPDATA_WIDTH-1:0] recv_data_in [(P_MESH-1):0];
wire  [(P_MESH-1):0] recv_data_valid;
wire  [(P_MESH-1):0] recv_data_par;
wire  [(P_MESH-1):0] recv_data_ready;
wire  [(P_MESH-1):0] recv_data_err;
wire  [CHIPDATA_WIDTH-1:0] send_data_out [(P_MESH-1):0];
wire  [(P_MESH-1):0] send_data_valid;
wire  [(P_MESH-1):0] send_data_par;
wire  [(P_MESH-1):0] send_data_ready;
wire  [(P_MESH-1):0] send_data_err;

// noc
noc #(
    .FW(FW),
    .B(B),
    .XW(XW),
    .YW(YW),
    .CONNECT(CONNECT),
    .P_MESH(P_MESH),
    .P_HIER(P_HIER),
    .FTW(FTW),
    .ATW(ATW),
    .CDW(CDW),
    .CAW(CAW),
    .NNW(NNW),
    .WW(WW),
    .WD(WD),
    .VW(VW),
    .SW(SW),
    .CODE_WIDTH(CODE_WIDTH),
    .DST_WIDTH(DST_WIDTH),
    .DST_DEPTH(DST_DEPTH)
)
the_noc
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // ctrl
    .tik(tik),
    // noc to chipconnection
    .flit_in(flit_in),
    .flit_in_wr(flit_in_wr),
    .flit_out(flit_out),
    .flit_out_wr(flit_out_wr),
    .credit_in(credit_in),
    .credit_out(credit_out)
);

genvar i,j;
generate

    for (i=0; i<(P_MESH-1); i=i+1) begin : mesh_port_loop

        for (j=0; j<CONNECT; j=j+1) begin
            assign flit_in[j][FW*(i+1)-1:FW*i] = flit_in_noc[i][FW*(j+1)-1:FW*j];
            assign flit_in_wr[j][i] = flit_in_wr_noc[i][j];
            assign flit_out_noc[i][FW*(j+1)-1:FW*j] = flit_out[j][FW*(i+1)-1:FW*i];
            assign flit_out_wr_noc[i][j] = flit_out_wr[j][i];
            assign credit_in[j][i] = credit_in_noc[i][j];
            assign credit_out_noc[i][j] = credit_out[j][i];
        end

        // chip connection
        chip_connection #(
            .FW(FW),
            .B(B),
            .CONNECT(CONNECT)
        )
        the_chip_connection
        (
            // system signal
            .clk(clk),
            .rst_n(rst_n),
            // noc
            .flit_in_wr_noc(flit_in_wr_noc[i]),
            .flit_in_noc(flit_in_noc[i]),
            .flit_out_wr_noc(flit_out_wr_noc[i]),
            .flit_out_noc(flit_out_noc[i]),
            .credit_in_noc(credit_in_noc[i]),
            .credit_out_noc(credit_out_noc[i]),
            // chip
            .data_in_wr(data_in_wr[i]),
            .data_in(data_in[i]),
            .data_out_wr(data_out_wr[i]),
            .data_out(data_out[i]),
            // inf full
            .send_fifo_full(send_fifo_full[i]),
            .connect_available(connect_available[i])
        );

        // interface
        chip_interface #(
            .FW(FW),
            .CONNECT(CONNECT),
            .CHIPDATA_WIDTH(CHIPDATA_WIDTH)
        )
        the_chip_interface
        (
            // system signal
            .clk(clk),
            .rst_n(rst_n),
            // chip connection
            .data_in_wr(data_in_wr[i]),
            .data_in(data_in[i]),
            .data_out_wr(data_out_wr[i]),
            .data_out(data_out[i]),
            .send_fifo_full(send_fifo_full[i]),
            .connect_available(connect_available[i]),
            // recv
            .recv_data_in(recv_data_in[i]),
            .recv_data_valid(recv_data_valid[i]),
            .recv_data_par(recv_data_par[i]),
            .recv_data_ready(recv_data_ready[i]),
            .recv_data_err(recv_data_err[i]),
            // send
            .send_data_out(send_data_out[i]),
            .send_data_valid(send_data_valid[i]),
            .send_data_par(send_data_par[i]),
            .send_data_ready(send_data_ready[i]),
            .send_data_err(send_data_err[i])
        );

    end

endgenerate
// port num
//  E = 0;
//  N = 1;
//  W = 2;
//  S = 3;
assign recv_data_in[0] = recv_data_in_E;
assign recv_data_valid[0] = recv_data_valid_E;
assign recv_data_par[0] = recv_data_par_E;
assign recv_data_ready_E = recv_data_ready[0];
assign recv_data_err_E = recv_data_err[0];
assign send_data_out_E = send_data_out[0];
assign send_data_valid_E = send_data_valid[0];
assign send_data_par_E = send_data_par[0];
assign send_data_ready[0] = send_data_ready_E;
assign send_data_err[0] = send_data_err_E;

assign recv_data_in[1] = recv_data_in_N;
assign recv_data_valid[1] = recv_data_valid_N;
assign recv_data_par[1] = recv_data_par_N;
assign recv_data_ready_N = recv_data_ready[1];
assign recv_data_err_N = recv_data_err[1];
assign send_data_out_N = send_data_out[1];
assign send_data_valid_N = send_data_valid[1];
assign send_data_par_N = send_data_par[1];
assign send_data_ready[1] = send_data_ready_N;
assign send_data_err[1] = send_data_err_N;

assign recv_data_in[2] = recv_data_in_W;
assign recv_data_valid[2] = recv_data_valid_W;
assign recv_data_par[2] = recv_data_par_W;
assign recv_data_ready_W = recv_data_ready[2];
assign recv_data_err_W = recv_data_err[2];
assign send_data_out_W = send_data_out[2];
assign send_data_valid_W = send_data_valid[2];
assign send_data_par_W = send_data_par[2];
assign send_data_ready[2] = send_data_ready_W;
assign send_data_err[2] = send_data_err_W;

assign recv_data_in[3] = recv_data_in_S;
assign recv_data_valid[3] = recv_data_valid_S;
assign recv_data_par[3] = recv_data_par_S;
assign recv_data_ready_S = recv_data_ready[3];
assign recv_data_err_S = recv_data_err[3];
assign send_data_out_S = send_data_out[3];
assign send_data_valid_S = send_data_valid[3];
assign send_data_par_S = send_data_par[3];
assign send_data_ready[3] = send_data_ready_S;
assign send_data_err[3] = send_data_err_S;

endmodule
