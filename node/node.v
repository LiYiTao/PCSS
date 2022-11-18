module node #(
    parameter B = 4,
    parameter FW  = 59, // flit width
    parameter FTW = 3,  // flit type width
    parameter ATW = 3,  // address type width
    parameter CDW = 21, // config data width
    parameter CAW = 15, // config addres width
    parameter NNW = 12, // neural number width
    parameter WW = 16, // weight width
    parameter WD = 6, // weight depth (8x8)
    parameter VW = 20, // Vm width
    parameter SW = 24, // spk width, (x,y,z)
    parameter XW = 4,
    parameter YW = 4,
    parameter CODE_WIDTH = 2, // spike code width
    parameter DST_WIDTH = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH = 4 // dst node depth
) (
    // system signals
    input  clk,
    input  rst_n,
    // ctrl
    input  tik,
    // credit
    input  credit_in,
    output credit_out,
    // flit
    input  flit_in_wr,
    input  [FW-1:0] flit_in,
    output flit_out_wr,
    output [FW-1:0] flit_out
);

// =============
//   connect
// =============

wire                  spk_in_config_we;
wire [FW-1:0]         spk_in_config_wdata;
wire                  spk_in_axon_vld;
wire [SW-1:0]         spk_in_axon_data;
wire [FTW-1:0]        spk_in_axon_type;

wire                  spk_out_config_full;

wire                  axon_busy;
wire [NNW-1:0]        axon_sd_vm_addr;
wire [WD-1:0]         axon_sd_wgt_addr;
wire                  axon_sd_vld;
wire                  axon_soma_we;
wire [NNW-1:0]        axon_soma_waddr;
wire [SW-1:0]         axon_soma_wdata;

wire [VW-1:0]         sd_soma_vm;

wire                  soma_spk_out_fire;

wire                  config_spk_in_credit;
wire                  config_spk_out_we;
wire [FW-1:0]         config_spk_out_wdata;
wire [SW-1:0]         config_spk_out_neuid;
wire                  config_spk_out_dst_we;
wire [DST_DEPTH-1:0]  config_spk_out_dst_waddr;
wire [DST_WIDTH-1:0]  config_spk_out_dst_wdata;
wire                  config_spk_out_dst_re;
wire [DST_DEPTH-1:0]  config_spk_out_dst_raddr;
wire [DST_WIDTH-1:0]  config_spk_out_dst_rdata;
wire [NNW-1:0]        config_axon_xk_yk;
wire [NNW-1:0]        config_axon_x_in;
wire [NNW-1:0]        config_axon_x_out;
wire [NNW-1:0]        config_axon_x_k;
wire [NNW-1:0]        config_axon_y_in;
wire [NNW-1:0]        config_axon_y_out;
wire [NNW-1:0]        config_axon_y_k;
wire [NNW-1:0]        config_axon_pad;
wire [NNW-1:0]        config_axon_stride_log;
wire [NNW-1:0]        config_sd_vm_addr;
wire                  config_sd_vld;
wire                  config_sd_clear;
wire                  config_sd_vm_we;
wire [NNW-1:0]        config_sd_vm_waddr;
wire [VW-1:0]         config_sd_vm_wdata;
wire                  config_sd_vm_re;
wire [NNW-1:0]        config_sd_vm_raddr;
wire [VW-1:0]         config_sd_vm_rdata;
wire                  config_sd_wgt_we;
wire [WD-1:0]         config_sd_wgt_waddr;
wire [WW-1:0]         config_sd_wgt_wdata;
wire                  config_sd_wgt_re;
wire [WD-1:0]         config_sd_wgt_raddr;
wire [WW-1:0]         config_sd_wgt_rdata;
wire                  config_soma_vld;
wire                  config_soma_clear;
wire [NNW-1:0]        config_soma_vm_addr;
wire                  config_soma_reset;
wire [CODE_WIDTH-1:0] config_soma_code;
wire [VW-1:0]         config_soma_vth;
wire [VW-1:0]         config_soma_leak;
wire [VW-1:0]         config_soma_random_seed;
wire                  config_soma_enable;
wire                  config_soma_vm_we;
wire [NNW-1:0]        config_soma_vm_waddr;
wire [VW-1:0]         config_soma_vm_wdata;
wire                  config_soma_vm_re;
wire [NNW-1:0]        config_soma_vm_raddr;
wire [VW-1:0]         config_soma_vm_rdata;

// spk_in
spk_in #(
    .B(B),
    .FW(FW),
    .FTW(FTW),
    .SW(SW)
)
the_spk_in
(
    // system signal
    .clk_spk_in(clk),
    .rst_n(rst_n),
    // node top
    .flit_in(flit_in),
    .flit_in_wr(flit_in_wr),
    .credit_out(credit_out),
    // config
    .config_spk_in_credit(config_spk_in_credit),
    .spk_in_config_we(spk_in_config_we),
    .spk_in_config_wdata(spk_in_config_wdata),
    // axon
    .axon_busy(axon_busy),
    .spk_in_axon_vld(spk_in_axon_vld),
    .spk_in_axon_data(spk_in_axon_data),
    .spk_in_axon_type(spk_in_axon_type)
);

// spk_out
spk_out #(
    .B(B),
    .FW(FW),
    .FTW(FTW),
    .SW(SW),
    .DST_WIDTH(DST_WIDTH),
    .DST_DEPTH(DST_DEPTH)
)
the_spk_out
(
    // system signal
    .clk_spk_out(clk),
    .rst_n(rst_n),
    // node top
    .credit_in(credit_in),
    .flit_out_wr(flit_out_wr),
    .flit_out(flit_out),
    // soma
    .soma_spk_out_fire(soma_spk_out_fire),
    // config
    .config_spk_out_we(config_spk_out_we),
    .config_spk_out_wdata(config_spk_out_wdata),
    .config_spk_out_neuid(config_spk_out_neuid),
    .spk_out_config_full(spk_out_config_full),
    .config_spk_out_dst_we(config_spk_out_dst_we),
    .config_spk_out_dst_waddr(config_spk_out_dst_waddr),
    .config_spk_out_dst_wdata(config_spk_out_dst_wdata),
    .config_spk_out_dst_re(config_spk_out_dst_re),
    .config_spk_out_dst_raddr(config_spk_out_dst_raddr),
    .config_spk_out_dst_rdata(config_spk_out_dst_rdata)
);

// axon
axon #(
    .NNW(NNW),
    .SW(SW),
    .WD(WD),
    .FTW(FTW)
)
the_axon
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // spk_in
    .spk_in_axon_vld(spk_in_axon_vld),
    .spk_in_axon_data(spk_in_axon_data),
    .spk_in_axon_type(spk_in_axon_type),
    .axon_busy(axon_busy),
    // sd
    .axon_sd_vm_addr(axon_sd_vm_addr),
    .axon_sd_wgt_addr(axon_sd_wgt_addr),
    .axon_sd_vld(axon_sd_vld),
    // config
    .xk_yk(config_axon_xk_yk),
    .x_in(config_axon_x_in),
    .x_out(config_axon_x_out),
    .x_k(config_axon_x_k),
    .y_in(config_axon_y_in),
    .y_out(config_axon_y_out),
    .y_k(config_axon_y_k),
    .pad(config_axon_pad),
    .stride_log(config_axon_stride_log),
    // soma
    .axon_soma_we(axon_soma_we),
    .axon_soma_waddr(axon_soma_waddr),
    .axon_soma_wdata(axon_soma_wdata)
);

// S & D
sd #(
    .FW(FW),
    .FTW(FTW),
    .CDW(CDW),
    .CAW(CAW),
    .NNW(NNW),
    .WW(WW),
    .WD(WD),
    .VW(VW),
    .SW(SW),
    .CODE_WIDTH(CODE_WIDTH),
    .DST_WIDTH(DST_WIDTH),
    .LAN_num()
)
the_sd
(
    // system signal
    .clk_SD(clk),
    .rst_n(rst_n),
    .tik(tik),
    // Axon
    .axon_sd_vm_addr(axon_sd_vm_addr),
    .axon_sd_wgt_addr(axon_sd_wgt_addr),
    .axon_sd_vld(axon_sd_vld),
    .axon_sd_lans(),
    // soma
    .sd_soma_vm(sd_soma_vm),
    // config
    .config_sd_vm_addr(config_sd_vm_addr),
    .config_sd_vld(config_sd_vld),
    .config_sd_clear(config_sd_clear),
    .config_sd_vm_we(config_sd_vm_we),
    .config_sd_vm_waddr(config_sd_vm_waddr),
    .config_sd_vm_wdata(config_sd_vm_wdata),
    .config_sd_wgt_we(config_sd_wgt_we),
    .config_sd_wgt_waddr(config_sd_wgt_waddr),
    .config_sd_wgt_wdata(config_sd_wgt_wdata),
    .config_sd_vm_re(config_sd_vm_re),
    .config_sd_vm_raddr(config_sd_vm_raddr),
    .config_sd_vm_rdata(config_sd_vm_rdata),
    .config_sd_wgt_re(config_sd_wgt_re),
    .config_sd_wgt_raddr(config_sd_wgt_raddr),
    .config_sd_wgt_rdata(config_sd_wgt_rdata)
);

// soma
soma #(
    .FW(FW),
    .FTW(FTW),
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
the_soma
(
    // system signal
    .clk_soma(clk),
    .rst_n(rst_n),
    // SD
    .sd_soma_vm(sd_soma_vm),
    // spk_out
    .soma_spk_out_fire(soma_spk_out_fire),
    // config
    .config_soma_code(config_soma_code),
    .config_soma_reset(config_soma_reset),
    .config_soma_vth(config_soma_vth),
    .config_soma_leak(config_soma_leak),
    .config_soma_vld(config_soma_vld),
    .config_soma_vm_addr(config_soma_vm_addr),
    .config_soma_clear(config_soma_clear),
    .config_soma_vm_we(config_soma_vm_we),
    .config_soma_vm_waddr(config_soma_vm_waddr),
    .config_soma_vm_wdata(config_soma_vm_wdata),
    .config_soma_vm_re(config_soma_vm_re),
    .config_soma_vm_raddr(config_soma_vm_raddr),
    .config_soma_vm_rdata(config_soma_vm_rdata),
    .config_soma_random_seed(config_soma_random_seed),
    .config_soma_enable(config_soma_enable)
);

// config
config_top #(
    .FW(FW),
    .FTW(FTW),
    .ATW(ATW),
    .CDW(CDW),
    .CAW(CAW),
    .NNW(NNW),
    .WW(WW),
    .WD(WD),
    .VW(VW),
    .SW(SW),
    .XW(XW),
    .YW(YW),
    .CODE_WIDTH(CODE_WIDTH),
    .DST_WIDTH(DST_WIDTH),
    .DST_DEPTH(DST_DEPTH)
)
the_config_top
(
    // system signal
    .clk_config(clk),
    .rst_n(rst_n),
    .tik(tik),
    // spk_in
    .spk_in_config_we(spk_in_config_we),
    .spk_in_config_wdata(spk_in_config_wdata),
    .config_spk_in_credit(config_spk_in_credit),
    // axon
    .axon_busy(axon_busy),
    .config_axon_xk_yk(config_axon_xk_yk),
    .config_axon_x_in(config_axon_x_in),
    .config_axon_x_out(config_axon_x_out),
    .config_axon_x_k(config_axon_x_k),
    .config_axon_y_in(config_axon_y_in),
    .config_axon_y_out(config_axon_y_out),
    .config_axon_y_k(config_axon_y_k),
    .config_axon_pad(config_axon_pad),
    .config_axon_stride_log(config_axon_stride_log),
    // S & D
    .config_sd_vm_addr(config_sd_vm_addr),
    .config_sd_vld(config_sd_vld),
    .config_sd_clear(config_sd_clear),
    // soma
    .config_soma_vld(config_soma_vld),
    .config_soma_clear(config_soma_clear),
    .config_soma_vm_addr(config_soma_vm_addr),
    .config_soma_reset(config_soma_reset),
    .config_soma_code(config_soma_code),
    .config_soma_vth(config_soma_vth),
    .config_soma_leak(config_soma_leak),
    .config_soma_random_seed(config_soma_random_seed),
    .config_soma_enable(config_soma_enable),
    // spk_out
    .spk_out_config_full(spk_out_config_full),
    .config_spk_out_neuid(config_spk_out_neuid),
    .config_spk_out_we(config_spk_out_we),
    .config_spk_out_wdata(config_spk_out_wdata),
    // write & read sd
    .config_sd_vm_we(config_sd_vm_we),
    .config_sd_vm_waddr(config_sd_vm_waddr),
    .config_sd_vm_wdata(config_sd_vm_wdata),
    .config_sd_vm_re(config_sd_vm_re),
    .config_sd_vm_raddr(config_sd_vm_raddr),
    .config_sd_vm_rdata(config_sd_vm_rdata),
    .config_sd_wgt_we(config_sd_wgt_we),
    .config_sd_wgt_waddr(config_sd_wgt_waddr),
    .config_sd_wgt_wdata(config_sd_wgt_wdata),
    .config_sd_wgt_re(config_sd_wgt_re),
    .config_sd_wgt_raddr(config_sd_wgt_raddr),
    .config_sd_wgt_rdata(config_sd_wgt_rdata),
    // write & read soma
    .config_soma_vm_we(config_soma_vm_we),
    .config_soma_vm_waddr(config_soma_vm_waddr),
    .config_soma_vm_wdata(config_soma_vm_wdata),
    .config_soma_vm_re(config_soma_vm_re),
    .config_soma_vm_raddr(config_soma_vm_raddr),
    .config_soma_vm_rdata(config_soma_vm_rdata),
    // write & read spk_out
    .config_spk_out_dst_we(config_spk_out_dst_we),
    .config_spk_out_dst_waddr(config_spk_out_dst_waddr),
    .config_spk_out_dst_wdata(config_spk_out_dst_wdata),
    .config_spk_out_dst_re(config_spk_out_dst_re),
    .config_spk_out_dst_raddr(config_spk_out_dst_raddr),
    .config_spk_out_dst_rdata(config_spk_out_dst_rdata)
);

endmodule
