//-------------------------------------------------------------------------
// 
//
// Filename         : configurator.v
// Author           : liyt
// Release version  : 1.0
// Release date     : 2020-08-12
// Description      :
//
//-------------------------------------------------------------------------

module configurator #(
    parameter CDW = 21, // config data width
    parameter CAW = 15, // config addres width
    parameter ATW = 3, // address type width
    parameter NNW = 12, // neural number width
    parameter WW = 16, // weight width
    parameter WD = 6, // weight depth (8x8)
    parameter VW = 20, // Vm width
    parameter SW = 24, // spk width, (x,y,z)
    parameter CODE_WIDTH = 2, // spike code width
    parameter DST_WIDTH = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH = 4 // dst node depth
) (
    // port list
    input  clk,
    input  rst_n,
    // sd
    output reg config_sd_vm_we,
    output [NNW-1:0] config_sd_vm_waddr,
    output [VW-1:0] config_sd_vm_wdata,
    output reg config_sd_vm_re,
    output [NNW-1:0] config_sd_vm_raddr,
    input  [VW-1:0] config_sd_vm_rdata,
    output reg config_sd_wgt_we,
    output [WD-1:0] config_sd_wgt_waddr,
    output [WW-1:0] config_sd_wgt_wdata,
    output reg config_sd_wgt_re,
    output [WD-1:0] config_sd_wgt_raddr,
    input  [WW-1:0] config_sd_wgt_rdata,
    // soma
    output reg config_soma_vm_we,
    output [NNW-1:0] config_soma_vm_waddr,
    output [VW-1:0] config_soma_vm_wdata,
    output reg config_soma_vm_re,
    output [NNW-1:0] config_soma_vm_raddr,
    input  [VW-1:0] config_soma_vm_rdata,
    output [VW-1:0] config_soma_random_seed,
    // spk_out
    output reg config_spk_out_dst_we,
    output [DST_DEPTH-1:0] config_spk_out_dst_waddr,
    output [DST_WIDTH-1:0] config_spk_out_dst_wdata,
    output reg config_spk_out_dst_re,
    output [DST_DEPTH-1:0] config_spk_out_dst_raddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_rdata,
    // config_ctrl
    input  config_we,
    input  [CAW-1:0] config_waddr,
    input  [CDW-1:0] config_wdata,
    input  config_re,
    input  [CAW-1:0] config_raddr,
    output reg [CDW-1:0] config_rdata,
    // param
    output [NNW-1:0] xk_yk, // x_k * y_k 
    output [NNW-1:0] x_in,
    output [NNW-1:0] x_out,
    output [NNW-1:0] x_k,
    output [NNW-1:0] y_in,
    output [NNW-1:0] y_out,
    output [NNW-1:0] y_k,
    output [SW/3-1:0] z_out,
    output [NNW-1:0] pad,
    output [NNW-1:0] stride_log,
    output [SW/3-1:0] x_start,
    output [SW/3-1:0] y_start,
    // ctrl signal
    output config_enable,
    output config_clear,
    input  config_clear_done,
    output [NNW-1:0] neu_num,
    output [CODE_WIDTH-1:0] spike_code,
    output config_soma_reset,
    output [VW-1:0] config_soma_vth,
    output [VW-1:0] config_soma_leak
);

// TODO reg bank depth
localparam REG_DEPTH = 5;

// address define
localparam CFG_REG  = 3'b000;
localparam WGT_MEM  = 3'b001;
localparam DST_MEM  = 3'b010;
localparam VM_MEM   = 3'b100;
localparam VM_BUF   = 3'b110;
localparam STATUS   = 5'h0;
localparam NEU_NUM  = 5'h1;
localparam VTH      = 5'h2;
localparam LEAK     = 5'h3;
localparam X_IN     = 5'h4;
localparam Y_IN     = 5'h5;
localparam Z_OUT    = 5'h6;
localparam X_K      = 5'h7;
localparam Y_K      = 5'h8;
localparam X_OUT    = 5'h9;
localparam Y_OUT    = 5'ha;
localparam PAD      = 5'hb;
localparam STRIDE_LOG = 5'hc;
localparam XK_YK      = 5'hd;
localparam RAND_SEED  = 5'he;
localparam X_START    = 5'hf;
localparam Y_START    = 5'h10;

// reg bank
reg  [CDW-1:0] nm_status;
reg  [CDW-1:0] nm_neu_num;
reg  [CDW-1:0] nm_vth;
reg  [CDW-1:0] nm_leak;
reg  [CDW-1:0] nm_x_in;
reg  [CDW-1:0] nm_y_in;
reg  [CDW-1:0] nm_x_k;
reg  [CDW-1:0] nm_y_k;
reg  [CDW-1:0] nm_x_out;
reg  [CDW-1:0] nm_y_out;
reg  [CDW-1:0] nm_z_out;
reg  [CDW-1:0] nm_pad;
reg  [CDW-1:0] nm_stride_log;
reg  [CDW-1:0] nm_xk_yk;
reg  [CDW-1:0] nm_random_seed;
reg  [CDW-1:0] nm_x_start;
reg  [CDW-1:0] nm_y_start;

wire nm_status_we;
wire nm_neu_num_we;
wire nm_vth_we;
wire nm_leak_we;
wire nm_x_in_we;
wire nm_y_in_we;
wire nm_z_out_we;
wire nm_x_k_we;
wire nm_y_k_we;
wire nm_x_out_we;
wire nm_y_out_we;
wire nm_pad_we;
wire nm_stride_log_we;
wire nm_xk_yk_we;
wire nm_random_seed_we;
wire nm_x_start_we;
wire nm_y_start_we;

reg  config_reg_we;
reg  config_reg_re;
reg  [CAW-1:0] config_raddr_dly;
wire [REG_DEPTH-1:0] config_reg_waddr;
wire [REG_DEPTH-1:0] config_reg_raddr;
wire [CDW-1:0] config_reg_wdata;
reg  [CDW-1:0] config_reg_rdata;

// output map
assign config_soma_random_seed = nm_random_seed[VW-1:0];
assign xk_yk = nm_xk_yk[NNW-1:0];
assign x_in = nm_x_in[NNW-1:0];
assign x_out = nm_x_out[NNW-1:0];
assign x_k = nm_x_k[NNW-1:0];
assign y_in = nm_y_in[NNW-1:0];
assign y_out = nm_y_out[NNW-1:0];
assign y_k = nm_y_k[NNW-1:0];
assign z_out = nm_z_out[SW/3-1:0];
assign pad = nm_pad[NNW-1:0];
assign stride_log = nm_stride_log[NNW-1:0];
assign config_enable = nm_status[0];
assign config_clear = nm_status[1];
assign config_soma_reset = nm_status[4];
assign spike_code = nm_status[3:2];
assign neu_num = nm_neu_num[NNW-1:0];
assign config_soma_vth = nm_vth[VW-1:0];
assign config_soma_leak = nm_leak[VW-1:0];
assign x_start = nm_x_start[SW/3-1:0];
assign y_start = nm_y_start[SW/3-1:0];

// write enable map
always @(*) begin
    config_reg_we = 1'b0;
    config_sd_vm_we = 1'b0;
    config_sd_wgt_we = 1'b0;
    config_soma_vm_we = 1'b0;
    config_spk_out_dst_we = 1'b0;
    case(config_waddr[CAW-1:CAW-ATW])
        CFG_REG : begin
            config_reg_we = config_we;
        end
        WGT_MEM : begin
            config_sd_wgt_we = config_we;
        end
        DST_MEM : begin
            config_spk_out_dst_we = config_we;
        end
        VM_MEM : begin
            config_soma_vm_we = config_we;
        end
        VM_BUF : begin
            config_sd_vm_we = config_we;
        end
        default : begin
            // free
        end
    endcase
end
// write address map
assign config_reg_waddr = config_waddr[REG_DEPTH-1:0];
assign config_sd_wgt_waddr = config_waddr[WD-1:0];
assign config_spk_out_dst_waddr = config_waddr[DST_DEPTH-1:0];
assign config_soma_vm_waddr = config_waddr[NNW-1:0];
assign config_sd_vm_waddr = config_waddr[NNW-1:0];

// write data map
assign config_reg_wdata = config_wdata;
assign config_sd_wgt_wdata = config_wdata[WW-1:0];
assign config_spk_out_dst_wdata = config_wdata[DST_WIDTH-1:0];
assign config_soma_vm_wdata = config_wdata[VW-1:0];
assign config_sd_vm_wdata = config_wdata[VW-1:0];

// read enable map
always @(*) begin
    case(config_raddr[CAW-1:CAW-ATW])
        CFG_REG : begin
            config_reg_re = config_re;
            config_sd_vm_re = 1'b0;
            config_sd_wgt_re = 1'b0;
            config_soma_vm_re = 1'b0;
            config_spk_out_dst_re = 1'b0;
        end
        WGT_MEM : begin
            config_sd_wgt_re = config_re;
            config_reg_re = 1'b0;
            config_sd_vm_re = 1'b0;
            config_soma_vm_re = 1'b0;
            config_spk_out_dst_re = 1'b0;
        end
        DST_MEM : begin
            config_spk_out_dst_re = config_re;
            config_reg_re = 1'b0;
            config_sd_vm_re = 1'b0;
            config_sd_wgt_re = 1'b0;
            config_soma_vm_re = 1'b0;
        end
        VM_MEM : begin
            config_soma_vm_re = config_re;
            config_reg_re = 1'b0;
            config_sd_vm_re = 1'b0;
            config_sd_wgt_re = 1'b0;
            config_spk_out_dst_re = 1'b0;
        end
        VM_BUF : begin
            config_sd_vm_re = config_re;
            config_reg_re = 1'b0;
            config_sd_wgt_re = 1'b0;
            config_soma_vm_re = 1'b0;
            config_spk_out_dst_re = 1'b0;
        end
        default : begin
            config_reg_re = 1'b0;
            config_sd_vm_re = 1'b0;
            config_sd_wgt_re = 1'b0;
            config_soma_vm_re = 1'b0;
            config_spk_out_dst_re = 1'b0;
        end
    endcase
end

// read address map
assign config_reg_raddr = config_raddr_dly[REG_DEPTH-1:0];
assign config_sd_wgt_raddr = config_raddr[WD-1:0];
assign config_spk_out_dst_raddr = config_raddr[DST_DEPTH-1:0];
assign config_soma_vm_raddr = config_raddr[NNW-1:0];
assign config_sd_vm_raddr = config_raddr[NNW-1:0];

// read data map
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        config_raddr_dly <= {CAW{1'b0}};
    end
    else begin
        config_raddr_dly <= config_raddr;
    end
end

always @( *) begin
    case (config_raddr_dly[CAW-1:CAW-ATW])
        CFG_REG : begin
            config_rdata = config_reg_rdata;
        end
        WGT_MEM : begin
            config_rdata = {{(CDW-WW){1'b0}},config_sd_wgt_rdata};
        end
        DST_MEM : begin
            config_rdata = {{(CDW-DST_WIDTH){1'b0}},config_spk_out_dst_rdata};
        end
        VM_MEM : begin
            config_rdata = {{(CDW-VW){1'b0}},config_soma_vm_rdata};
        end
        VM_BUF : begin
            config_rdata = {{(CDW-VW){1'b0}},config_sd_vm_rdata};
        end
        default : begin
            config_rdata = {(CDW/4){4'hE}};
        end
    endcase
end

always @(*) begin
    case (config_reg_raddr)
        STATUS : begin
            config_reg_rdata = nm_status;
        end
        NEU_NUM : begin
            config_reg_rdata = nm_neu_num;
        end
        VTH : begin
            config_reg_rdata = nm_vth;
        end
        LEAK : begin
            config_reg_rdata = nm_leak;
        end
        X_IN : begin
            config_reg_rdata = nm_x_in;
        end
        Y_IN : begin
            config_reg_rdata = nm_y_in;
        end
        Z_OUT : begin
            config_reg_rdata = nm_z_out;
        end
        X_K : begin
            config_reg_rdata = nm_x_k;
        end
        Y_K : begin
            config_reg_rdata = nm_y_k;
        end
        X_OUT : begin
            config_reg_rdata = nm_x_out;
        end
        Y_OUT : begin
            config_reg_rdata = nm_y_out;
        end
        XK_YK : begin
            config_reg_rdata = nm_xk_yk;
        end
        PAD : begin
            config_reg_rdata = nm_pad;
        end
        STRIDE_LOG : begin
            config_reg_rdata = nm_stride_log;
        end
        RAND_SEED : begin
            config_reg_rdata = nm_random_seed;
        end
        X_START : begin
            config_reg_rdata = nm_x_start;
        end
        Y_START : begin
            config_reg_rdata = nm_y_start;
        end
        default : begin
            config_reg_rdata = {(CDW/4){4'hE}};
        end
    endcase
end

// status reg
assign nm_status_we = config_reg_we && (config_reg_waddr == STATUS);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_status <= {CDW{1'b0}};
    end
    else if (nm_status_we) begin
        nm_status <= config_reg_wdata;
    end
    else if (config_clear_done) begin
        nm_status[1] <= 1'b0;
    end
end

// neu_num reg
assign nm_neu_num_we = config_reg_we && (config_reg_waddr == NEU_NUM);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_neu_num <= {CDW{1'b0}};
    end
    else if (nm_neu_num_we) begin
        nm_neu_num <= config_reg_wdata;
    end
end

// vth reg
assign nm_vth_we = config_reg_we && (config_reg_waddr == VTH);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_vth <= {CDW{1'b0}};
    end
    else if (nm_vth_we) begin
        nm_vth <= config_reg_wdata;
    end
end

// leak reg
assign nm_leak_we = config_reg_we && (config_reg_waddr == LEAK);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_leak <= {CDW{1'b0}};
    end
    else if (nm_leak_we) begin
        nm_leak <= config_reg_wdata;
    end
end

// x_in reg
assign nm_x_in_we = config_reg_we && (config_reg_waddr == X_IN);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_x_in <= {CDW{1'b0}};
    end
    else if (nm_x_in_we) begin
        nm_x_in <= config_reg_wdata;
    end
end

// y_in reg
assign nm_y_in_we = config_reg_we && (config_reg_waddr == Y_IN);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_y_in <= {CDW{1'b0}};
    end
    else if (nm_y_in_we) begin
        nm_y_in <= config_reg_wdata;
    end
end

// z reg
assign nm_z_out_we = config_reg_we && (config_reg_waddr == Z_OUT);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_z_out <= {CDW{1'b0}};
    end
    else if (nm_z_out_we) begin
        nm_z_out <= config_reg_wdata;
    end
end

// x_k reg
assign nm_x_k_we = config_reg_we && (config_reg_waddr == X_K);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_x_k <= {CDW{1'b0}};
    end
    else if (nm_x_k_we) begin
        nm_x_k <= config_reg_wdata;
    end
end

// y_k reg
assign nm_y_k_we = config_reg_we && (config_reg_waddr == Y_K);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_y_k <= {CDW{1'b0}};
    end
    else if (nm_y_k_we) begin
        nm_y_k <= config_reg_wdata;
    end
end

// x_out reg
assign nm_x_out_we = config_reg_we && (config_reg_waddr == X_OUT);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_x_out <= {CDW{1'b0}};
    end
    else if (nm_x_out_we) begin
        nm_x_out <= config_reg_wdata;
    end
end

// y_out reg
assign nm_y_out_we = config_reg_we && (config_reg_waddr == Y_OUT);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_y_out <= {CDW{1'b0}};
    end
    else if (nm_y_out_we) begin
        nm_y_out <= config_reg_wdata;
    end
end

// xk_yk reg
assign nm_xk_yk_we = config_reg_we && (config_reg_waddr == XK_YK);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_xk_yk <= {CDW{1'b0}};
    end
    else if (nm_xk_yk_we) begin
        nm_xk_yk <= config_reg_wdata;
    end
end

// pad reg
assign nm_pad_we = config_reg_we && (config_reg_waddr == PAD);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_pad <= {CDW{1'b0}};
    end
    else if (nm_pad_we) begin
        nm_pad <= config_reg_wdata;
    end
end

// stride_log reg
assign nm_stride_log_we = config_reg_we && (config_reg_waddr == STRIDE_LOG);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_stride_log <= {CDW{1'b0}};
    end
    else if (nm_stride_log_we) begin
        nm_stride_log <= config_reg_wdata;
    end
end

// random seed reg
assign nm_random_seed_we = config_reg_we && (config_reg_waddr == RAND_SEED);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_random_seed <= {CDW{1'b0}};
    end
    else if (nm_random_seed_we) begin
        nm_random_seed <= config_reg_wdata;
    end
end

// x_start reg
assign nm_x_start_we = config_reg_we && (config_reg_waddr == X_START);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_x_start <= {CDW{1'b0}};
    end
    else if (nm_x_start_we) begin
        nm_x_start <= config_reg_wdata;
    end
end

// y_start reg
assign nm_y_start_we = config_reg_we && (config_reg_waddr == Y_START);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nm_y_start <= {CDW{1'b0}};
    end
    else if (nm_y_start_we) begin
        nm_y_start <= config_reg_wdata;
    end
end

endmodule
