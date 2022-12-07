//-------------------------------------------------------------------------
// 
//
// Filename         : work_ctrl.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-22
// Description      :
//
//-------------------------------------------------------------------------

module work_ctrl #(
    parameter NNW = 12, // neural number width
    parameter VW = 20, // Vm width
    parameter SW = 24, // spk width, (x,y,z)
    parameter CODE_WIDTH = 2 // spike code width
) (
    // port list
    input clk,
    input rst_n,
    // ctrl
    input tik,
    // SD
    output config_sd_vld,
    output [NNW-1:0] config_sd_vm_addr,
    output config_sd_clear,
    output config_sd_start,
    // Soma
    output config_soma_vld,
    output [NNW-1:0] config_soma_vm_addr,
    output config_soma_clear,
    // Spk_out
    input  spk_out_config_full,
    output reg [SW-1:0] config_spk_out_neuid,
    // config ctrl
    output work_config_busy,
    // configurator
    input  config_enable,
    input  config_clear,
    output config_clear_done,
    input  [CODE_WIDTH-1:0] spike_code,
    input  [NNW-1:0] neu_num,
    input  [NNW-1:0] x_in,
    input  [NNW-1:0] y_in,
    input  [SW/3-1:0] x_start,
    input  [SW/3-1:0] y_start,
    input  [SW/3-1:0] z_out
);

// work FSM
localparam      IDLE          = 3'b000;
localparam      INFERENCE     = 3'b001;
localparam      I_WAIT        = 3'b010;
localparam      CODE_C        = 3'b011;
localparam      C_WAIT        = 3'b100;
localparam      CODE_P        = 3'b101;
localparam      P_WAIT        = 3'b110;
localparam      CLEAR         = 3'b111;
// spike code
localparam      LIF           = 2'b00;
localparam      CODE_COUNT    = 2'b01;
localparam      CODE_POISSON  = 2'b10;

reg  tik_d1;
reg  tik_d2;
reg  tik_d3;
wire start;
reg  [NNW-1:0] neu_id;
reg  [SW/3-1:0] x_s;
reg  [SW/3-1:0] y_s;
wire neu_vld;

// work state
reg     [2:0]   cs;
reg     [2:0]   ns;

// generate current state
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end
// generate next state
always @(*) begin
    case(cs)
        IDLE : begin
            if (!config_enable) begin
                if (config_clear) begin
                    ns = CLEAR;
                end
                else begin
                    ns = IDLE;
                end
            end
            else if (start && !spk_out_config_full) begin
                if (spike_code == LIF) begin
                    ns = INFERENCE;
                end
                else if(spike_code == CODE_COUNT) begin
                    ns = CODE_C;
                end
                else if(spike_code == CODE_POISSON) begin
                    ns = CODE_P;
                end
                else begin
                    ns = IDLE;
                end
            end
            else begin
                ns = IDLE;
            end
        end
        INFERENCE : begin
            if (spk_out_config_full) begin
                ns = I_WAIT;
            end
            else if (neu_id < neu_num) begin
                ns = INFERENCE;
            end
            else begin
                ns = IDLE;
            end
        end
        I_WAIT : begin
            if (spk_out_config_full) begin
                ns = I_WAIT;
            end
            else begin
                ns = INFERENCE;
            end
        end
        CODE_C : begin
            if (spk_out_config_full) begin
                ns = C_WAIT;
            end
            else if (neu_id < neu_num) begin
                ns = CODE_C;
            end
            else begin
                ns = IDLE;
            end
        end
        C_WAIT : begin
            if (spk_out_config_full) begin
                ns = C_WAIT;
            end
            else begin
                ns = CODE_C;
            end
        end
        CODE_P : begin
            if (spk_out_config_full) begin
                ns = P_WAIT;
            end
            else if (neu_id < neu_num) begin
                ns = CODE_P;
            end
            else begin
                ns = IDLE;
            end
        end
        P_WAIT : begin
            if (spk_out_config_full) begin
                ns = P_WAIT;
            end
            else begin
                ns = CODE_P;
            end
        end
        CLEAR : begin
            if (neu_id < neu_num) begin
                ns = CLEAR;
            end
            else begin
                ns = IDLE;
            end
        end
        default : begin // IDLE
            ns = IDLE;
        end
    endcase
end
// generate output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        neu_id <= {NNW{1'b0}};
        x_s <= {(SW/3){1'b0}};
        y_s <= {(SW/3){1'b0}};
    end
    else if (((cs == IDLE) && (ns != IDLE)) ||
             ((cs != IDLE) && (ns == IDLE))) begin
        neu_id <= {NNW{1'b0}};
        x_s <= {(SW/3){1'b0}};
        y_s <= {(SW/3){1'b0}};
    end
    else if ((((cs == INFERENCE) || (cs == I_WAIT)) && (ns == INFERENCE)) ||
             (((cs == CODE_C) || (cs == C_WAIT)) && (ns == CODE_C)) ||
             (((cs == CODE_P) || (cs == P_WAIT)) && (ns == CODE_P)) ||
             ((cs == CLEAR) && (ns == CLEAR))) begin
        neu_id <= neu_id + 1'b1;
        if (x_s < x_in[SW/3-1:0]) begin // [x_in-1 : 0]
            x_s <= x_s + 1'b1;
        end
        else if (y_s < y_in[SW/3-1:0]) begin // [y_in-1 : 0]
            x_s <= {(SW/3){1'b0}};
            y_s <= y_s + 1'b1;
        end
        else begin // (x_s >= x_in) && (y_s >= y_in)
            x_s <= {(SW/3){1'b0}};
            y_s <= {(SW/3){1'b0}};
        end
    end
end

assign neu_vld = (cs == INFERENCE) || (cs == CODE_C) || (cs == CODE_P) || (cs == CLEAR);
assign config_sd_vld = neu_vld;
assign config_soma_vld = neu_vld;
assign config_sd_vm_addr = neu_id;
assign config_soma_vm_addr = neu_id;
assign config_clear_done = (cs == CLEAR) && (ns == IDLE);
assign config_sd_clear = (cs == CLEAR);
assign config_sd_start = start;
assign config_soma_clear = (cs == CLEAR);
assign work_config_busy = cs != IDLE;

// neu_id dly
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        config_spk_out_neuid <= {SW{1'b0}};
    end
    else begin
        config_spk_out_neuid <= {z_out, y_s+y_start, x_s+x_start};
    end
end

// tik negedge
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tik_d1 <= 1'b0;
        tik_d2 <= 1'b0;
        tik_d3 <= 1'b0;
    end
    else begin
        tik_d1 <= tik;
        tik_d2 <= tik_d1;
        tik_d3 <= tik_d2;
    end
end
assign start = tik_d3 && !tik_d2 && config_enable;


endmodule
