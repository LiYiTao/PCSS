//-------------------------------------------------------------------------
//
// Filename         : config_ctrl.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-21
// Description      :
//
//-------------------------------------------------------------------------

module config_ctrl #(
    parameter FW  = 59, // flit width
    parameter FTW = 3, // flit type width
    parameter ATW = 3, // address type width
    parameter CDW = 21, // config data width
    parameter CAW = 15, // config addres width
    parameter XW = 4,
    parameter YW = 4
) (
    // port list
    input  clk,
    input  rst_n,
    // spk_in
    input  spk_in_config_we,
    input  [FW-1:0] spk_in_config_wdata,
    output config_spk_in_credit,
    // SD
    input axon_busy, // can't read and write sd
    // spk_out
    output config_spk_out_we,
    output reg [FW-1:0] config_spk_out_wdata,
    input  spk_out_conifg_full,
    // work_ctrl
    input  work_config_busy,
    //configurator
    output config_we,
    output reg [CAW-1:0] config_waddr,
    output reg [CDW-1:0] config_wdata,
    output config_re,
    output reg [CAW-1:0] config_raddr,
    input  [CDW-1:0] config_rdata
);


wire [FTW-1:0] pkg_type;
wire config_write_reg;
wire config_write_sd;
wire config_write_soma_spk;
wire config_read_reg;
wire config_read_sd;
wire config_read_soma_spk;
wire write_not_busy;
wire read_not_busy;

// TODO start of router bit in flit
localparam R_FLG = 36;
localparam X_FLG = R_FLG + 12;
localparam XY_OUT = 8'h07; // send out (7,0)

// addres define
localparam CFG_REG  = 3'b000;
localparam WGT_MEM  = 3'b001;
localparam DST_MEM  = 3'b010;
localparam VM_MEM   = 3'b100;
localparam VM_BUF   = 3'b110;

// packet type
localparam SPIKE    = 3'b000;
localparam DATA     = 3'b001;
localparam DATA_END = 3'b010;
localparam WRITE    = 3'b110;
localparam READ     = 3'b111;

// FSM
localparam IDLE     = 3'd0;
localparam W_WAIT   = 3'd1;
localparam R_READ   = 3'd2;
localparam R_WAIT   = 3'd3;
localparam R_SEND   = 3'd4;

// current and next state
reg [2:0] cs;
reg [2:0] ns;

// generate current state
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end

// read & write busy
assign pkg_type = spk_in_config_we ? spk_in_config_wdata[FW-1:FW-FTW] : {FTW{1'b0}};
assign config_write_reg = config_waddr[CAW-1:CAW-ATW] == CFG_REG;
assign config_write_sd  = (config_waddr[CAW-1:CAW-ATW] == WGT_MEM) || (config_waddr[CAW-1:CAW-ATW] == VM_BUF);
assign config_write_soma_spk = (config_waddr[CAW-1:CAW-ATW] == VM_MEM) || (config_waddr[CAW-1:CAW-ATW] == DST_MEM);
assign config_read_reg = config_raddr[CAW-1:CAW-ATW] == CFG_REG;
assign config_read_sd  = (config_raddr[CAW-1:CAW-ATW] == WGT_MEM) || (config_raddr[CAW-1:CAW-ATW] == VM_BUF);
assign config_read_soma_spk = (config_raddr[CAW-1:CAW-ATW] == VM_MEM) || (config_raddr[CAW-1:CAW-ATW] == DST_MEM);
assign write_not_busy = config_write_reg || (config_write_sd && !axon_busy) || (config_write_soma_spk && !work_config_busy);
assign read_not_busy = config_read_reg || (config_read_sd && !axon_busy) || (config_read_soma_spk && !work_config_busy);

// generate next state
always @(*) begin
    case(cs)
        IDLE : begin
            if (spk_in_config_we && (pkg_type == WRITE)) begin
                ns = W_WAIT;
            end
            else if (spk_in_config_we && (pkg_type == READ)) begin
                ns = R_READ;
            end
            else begin
                ns = IDLE;
            end
        end
        W_WAIT : begin
            if (!write_not_busy) // write busy
               ns = W_WAIT;
            else
               ns = IDLE;
        end
        R_READ : begin 
            if (!read_not_busy) begin // read busy
                ns = R_READ;
            end
            else begin
                ns = R_WAIT;
            end
        end
        R_WAIT : begin
            ns = R_SEND;
        end
        R_SEND : begin
            if ((!spk_out_conifg_full) && (!work_config_busy)) begin
                ns = IDLE;
            end
            else begin
                ns = R_SEND;
            end
        end
        default : begin // IDLE
            ns = IDLE;
        end 
    endcase
end
//generate output
assign config_we            = ((ns == IDLE) && (cs == W_WAIT));

assign config_spk_in_credit = ((ns == IDLE) && 
                              ((cs == W_WAIT) || (cs == R_SEND)));

assign config_re            = (cs == R_READ);

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        config_waddr <= {CAW{1'b0}};
        config_raddr <= {CAW{1'b0}};
        config_wdata <= {CDW{1'b0}};
        config_spk_out_wdata <= {FW{1'b0}};
    end
    else begin
        case(cs)
            IDLE : begin
                if (ns == W_WAIT) begin
                    config_waddr <= spk_in_config_wdata[CDW+CAW-1:CDW]; 
                    config_wdata <= spk_in_config_wdata[CDW-1:0]; 
                end
                else if (ns == R_READ) begin
                    config_spk_out_wdata[FW-1:FW-FTW] <= READ; // pkg type
                    config_spk_out_wdata[X_FLG+XW+YW-1:X_FLG] <= XY_OUT; // dst [55:48]
                    config_spk_out_wdata[R_FLG+11:R_FLG] <= 12'b0;
                    config_spk_out_wdata[CDW+CAW-1:CDW] <= spk_in_config_wdata[CDW+CAW-1:CDW]; // read addr
                    config_raddr   <= spk_in_config_wdata[CDW+CAW-1:CDW];
                end
            end
            W_WAIT : begin
                //free
            end
            R_READ : begin 
                //free
            end
            R_WAIT : begin
                config_spk_out_wdata[CDW-1:0] <= config_rdata;
            end
            R_SEND : begin
                //free
            end
            default : begin // IDLE
                config_waddr <= {CAW{1'b0}};
                config_raddr <= {CAW{1'b0}};
                config_wdata <= {CDW{1'b0}};
                config_spk_out_wdata <= {FW{1'b0}};
            end 
        endcase
    end
end


endmodule
