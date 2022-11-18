//-------------------------------------------------------------------------
//
// Filename         : config_top.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-21
// Description      :
//
//-------------------------------------------------------------------------

module config_top #(
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
    // port list
    input  clk_config,
    input  rst_n,
    input  tik,
    // spk_in
    input  spk_in_config_we,
    input  [FW-1:0] spk_in_config_wdata,
    output config_spk_in_credit,
    // Axon
    input  axon_busy,
    output [NNW-1:0] config_axon_xk_yk,
    output [NNW-1:0] config_axon_x_in,
    output [NNW-1:0] config_axon_x_out,
    output [NNW-1:0] config_axon_x_k,
    output [NNW-1:0] config_axon_y_in,
    output [NNW-1:0] config_axon_y_out,
    output [NNW-1:0] config_axon_y_k,
    output [NNW-1:0] config_axon_pad,
    output [NNW-1:0] config_axon_stride_log,
    // SD
    output [NNW-1:0] config_sd_vm_addr,
    output config_sd_vld,
    output config_sd_clear,
    // soma
    output config_soma_vld,
    output config_soma_clear,
    output [NNW-1:0] config_soma_vm_addr,
    output config_soma_reset,
    output [CODE_WIDTH-1:0] config_soma_code,
    output [VW-1:0] config_soma_vth,
    output [VW-1:0] config_soma_leak,
    output [VW-1:0] config_soma_random_seed,
    output config_soma_enable,
    // spk_out
    input  spk_out_config_full,
    output [SW-1:0] config_spk_out_neuid,
    output config_spk_out_we,
    output [CDW-1:0] config_spk_out_wdata,
    // write & read sd
    output config_sd_vm_we,
    output [NNW-1:0] config_sd_vm_waddr,
    output [VW-1:0] config_sd_vm_wdata,
    output config_sd_vm_re,
    output [NNW-1:0] config_sd_vm_raddr,
    input  [VW-1:0] config_sd_vm_rdata,
    output config_sd_wgt_we,
    output [WD-1:0] config_sd_wgt_waddr,
    output [WW-1:0] config_sd_wgt_wdata,
    output config_sd_wgt_re,
    output [WD-1:0] config_sd_wgt_raddr,
    input  [WW-1:0] config_sd_wgt_rdata,
    // write & read soma
    output config_soma_vm_we,
    output [NNW-1:0] config_soma_vm_waddr,
    output [VW-1:0] config_soma_vm_wdata,
    output config_soma_vm_re,
    output [NNW-1:0] config_soma_vm_raddr,
    input  [VW-1:0] config_soma_vm_rdata,
    // write & read spk_out
    output config_spk_out_dst_we,
    output [DST_DEPTH-1:0] config_spk_out_dst_waddr,
    output [DST_WIDTH-1:0] config_spk_out_dst_wdata,
    output config_spk_out_dst_re,
    output [DST_DEPTH-1:0] config_spk_out_dst_raddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_rdata
);

wire config_we;
wire [CAW-1:0] config_waddr;
wire [CDW-1:0] config_wdata;
wire config_re;
wire [CAW-1:0] config_raddr;
wire [CDW-1:0] config_rdata;
wire config_enable;
wire config_clear;
wire config_clear_done;
wire [NNW-1:0] neu_num;
wire [CODE_WIDTH-1:0] spike_code;
wire work_config_busy;
wire [SW/3-1:0] config_work_z_out;

// generate output
assign config_soma_code = spike_code;
assign config_soma_enable = config_enable;

// config ctrl
config_ctrl #(
    .FW(FW),
    .FTW(FTW),
    .ATW(ATW),
    .CDW(CDW),
    .CAW(CAW),
    .XW(XW),
    .YW(YW)
)
the_config_ctrl
(
    // system signal
    .clk(clk_config),
    .rst_n(rst_n),
    // spk_in
    .spk_in_config_we(spk_in_config_we),
    .spk_in_config_wdata(spk_in_config_wdata),
    .config_spk_in_credit(config_spk_in_credit),
    // SD (AXON)
    .axon_busy(axon_busy),
    // spk_out
    .config_spk_out_we(config_spk_out_we),
    .config_spk_out_wdata(config_spk_out_wdata),
    .spk_out_config_full(spk_out_config_full),
    // work_ctrl
    .work_config_busy(work_config_busy),
    // configurator
    .config_we(config_we),
    .config_waddr(config_waddr),
    .config_wdata(config_wdata),
    .config_re(config_re),
    .config_raddr(config_raddr),
    .config_rdata(config_rdata)
);

// work_ctrl
work_ctrl #(
    .NNW(NNW),
    .VW(VW),
    .SW(SW),
    .CODE_WIDTH(CODE_WIDTH)
)
the_work_ctrl
(
    // system signal
    .clk(clk_config),
    .rst_n(rst_n),
    // ctrl
    .tik(tik),
    // SD
    .config_sd_vld(config_sd_vld),
    .config_sd_vm_addr(config_sd_vm_addr),
    .config_sd_clear(config_sd_clear),
    // Soma
    .config_soma_vld(config_soma_vld),
    .config_soma_vm_addr(config_soma_vm_addr),
    .config_soma_clear(config_soma_clear),
    // Spk_out
    .spk_out_config_full(spk_out_config_full),
    .config_spk_out_neuid(config_spk_out_neuid),
    // config ctrl
    .work_config_busy(work_config_busy),
    // configurator
    .config_enable(config_enable),
    .config_clear(config_clear),
    .config_clear_done(config_clear_done),
    .spike_code(spike_code),
    .neu_num(neu_num),
    .x_in(config_axon_x_in),
    .y_in(config_axon_y_in),
    .z_out(config_work_z_out)
);

// configurator
configurator #(
    .CDW(CDW),
    .CAW(CAW),
    .ATW(ATW),
    .NNW(NNW),
    .WW(WW),
    .WD(WD),
    .VW(VW),
    .SW(SW),
    .CODE_WIDTH(CODE_WIDTH),
    .DST_WIDTH(DST_WIDTH),
    .DST_DEPTH(DST_DEPTH)
)
the_configurator
(
    // system signal
    .clk(clk_config),
    .rst_n(rst_n),
    // SD
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
    // soma
    .config_soma_vm_we(config_soma_vm_we),
    .config_soma_vm_waddr(config_soma_vm_waddr),
    .config_soma_vm_wdata(config_soma_vm_wdata),
    .config_soma_vm_re(config_soma_vm_re),
    .config_soma_vm_raddr(config_soma_vm_raddr),
    .config_soma_vm_rdata(config_soma_vm_rdata),
    .config_soma_random_seed(config_soma_random_seed),
    // spk_out
    .config_spk_out_dst_we(config_spk_out_dst_we),
    .config_spk_out_dst_waddr(config_spk_out_dst_waddr),
    .config_spk_out_dst_wdata(config_spk_out_dst_wdata),
    .config_spk_out_dst_re(config_spk_out_dst_re),
    .config_spk_out_dst_raddr(config_spk_out_dst_raddr),
    .config_spk_out_dst_rdata(config_spk_out_dst_rdata),
    // config_ctrl
    .config_we(config_we),
    .config_waddr(config_waddr),
    .config_wdata(config_wdata),
    .config_re(config_re),
    .config_raddr(config_raddr),
    .config_rdata(config_rdata),
    // param
    .xk_yk(config_axon_xk_yk),
    .x_in(config_axon_x_in),
    .x_out(config_axon_x_out),
    .x_k(config_axon_x_k),
    .y_in(config_axon_y_in),
    .y_out(config_axon_y_out),
    .y_k(config_axon_y_k),
    .z_out(config_work_z_out),
    .pad(config_axon_pad),
    .stride_log(config_axon_stride_log),
    // ctrl signal
    .config_enable(config_enable),
    .config_clear(config_clear),
    .config_clear_done(config_clear_done),
    .neu_num(neu_num),
    .spike_code(spike_code),
    .config_soma_reset(config_soma_reset),
    .config_soma_vth(config_soma_vth),
    .config_soma_leak(config_soma_leak)
);



endmodule
