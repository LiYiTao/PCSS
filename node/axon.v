module axon #(
    parameter NNW = 12,
    parameter SW = 24,
    parameter WD = 6,
    parameter FTW = 3
) (
    // system signal
    input  clk,
    input  rst_n,
    // spk_in
    input  spk_in_axon_vld,
    input  [SW-1:0] spk_in_axon_data,
    input  [FTW-1:0] spk_in_axon_type,
    output axon_busy,
    // sd
    output [NNW-1:0] axon_sd_vm_addr,
    output [WD-1:0] axon_sd_wgt_addr,
    output axon_sd_vld,
    // config
    input  [NNW-1:0] xk_yk, // x_k * y_k 
    input  [NNW-1:0] x_in,
    input  [NNW-1:0] x_out,
    input  [NNW-1:0] x_k,
    input  [NNW-1:0] y_in,
    input  [NNW-1:0] y_out,
    input  [NNW-1:0] y_k,
    input  [NNW-1:0] pad,
    input  [NNW-1:0] stride_log,
    // soma
    output reg axon_soma_we,
    output reg [NNW-1:0] axon_soma_waddr,
    output reg [SW-1:0] axon_soma_wdata
);

wire [SW/3-1:0] xs; // x_spike
wire [SW/3-1:0] ys; // y_spike
wire [SW/3-1:0] zs; // z_spike
reg  [NNW-1:0] xl;  // x_local
reg  [NNW-1:0] yl;  // y_local
reg  [NNW-1:0] xw;  // x_weight
reg  [NNW-1:0] yw;  // y_weight
reg  [NNW-1:0] zw;  // z_weight
reg  [NNW-1:0] xl_start;
reg  [NNW-1:0] xl_start_hold;
reg  [NNW-1:0] xl_end;
reg  [NNW-1:0] xl_end_hold;
reg  [NNW-1:0] yl_start;
reg  [NNW-1:0] yl_end;
reg  [NNW-1:0] yl_end_hold;
reg  [NNW-1:0] xw_start;
reg  [NNW-1:0] xw_start_hold;
reg  [NNW-1:0] yw_start;
reg  [NNW-1:0] x_pre;
reg  [NNW-1:0] y_pre;
wire [NNW-1:0] stride;
reg  [NNW-1:0] x_pre_stride;
reg  [NNW-1:0] y_pre_stride;

// FSM
localparam IDLE     = 2'b00;
localparam SLIDE    = 2'b01;
localparam INPUT    = 2'b10;

// packet type
localparam SPIKE    = 3'b000;
localparam DATA     = 3'b001;
localparam DATA_END = 3'b010;
localparam WRITE    = 3'b110;
localparam READ     = 3'b111;

// current and next state
reg [1:0] cs;
reg [1:0] ns;

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
            if (spk_in_axon_vld) begin
                if (spk_in_axon_type == SPIKE) ns = SLIDE;
                else if (spk_in_axon_type == DATA) ns = INPUT;
                else ns = IDLE;
            end
            else ns = IDLE;
        end
        SLIDE : begin
            if ((xl >= xl_end_hold) && (yl >= yl_end_hold)) ns = IDLE;
            else ns = SLIDE;
        end
        INPUT : begin
            if (spk_in_axon_vld && (spk_in_axon_type == DATA_END)) ns = IDLE;
            else ns = INPUT;
        end
        default : begin // IDLE
            ns = IDLE;
        end 
    endcase
end

// generate output
assign axon_sd_vld = cs == SLIDE;
assign axon_busy = (cs == SLIDE) || (ns == SLIDE);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xl <= {NNW{1'b0}};
        xl_start_hold <= {NNW{1'b0}};
        yl <= {NNW{1'b0}};
        xl_end_hold <= {NNW{1'b0}};
        yl_end_hold <= {NNW{1'b0}};
        xw <= {NNW{1'b0}};
        xw_start_hold <= {NNW{1'b0}};
        yw <= {NNW{1'b0}};
        zw <= {NNW{1'b0}};
        axon_soma_we <= 1'b0;
        axon_soma_waddr <= {NNW{1'b0}};
        axon_soma_wdata <= {SW{1'b0}};
    end
    else begin
        case (cs)
            IDLE : begin
                if (ns == SLIDE) begin
                    xl <= xl_start;
                    xl_start_hold <= xl_start;
                    yl <= yl_start;
                    xl_end_hold <= xl_end;
                    yl_end_hold <= yl_end;
                    xw <= xw_start;
                    xw_start_hold <= xw_start;
                    yw <= yw_start;
                    zw <= zs;
                end 
                else if (ns == INPUT) begin
                    axon_soma_we <= 1'b1;
                    axon_soma_waddr <= {NNW{1'b0}};
                    axon_soma_wdata <= spk_in_axon_data;
                end
                else axon_soma_we <= 1'b0;
            end
            SLIDE : begin
                if (xl < xl_end_hold) begin
                    xl <= xl + 1'b1;
                    xw <= xw - stride;
                end
                else begin // xl >= xl_end
                    xl <= xl_start_hold;
                    xw <= xw_start_hold;
                    if (yl < yl_end_hold) begin
                        yl <= yl + 1'b1;
                        yw <= yw - stride;
                    end
                end
            end
            INPUT : begin
                if (spk_in_axon_vld && ((spk_in_axon_type == DATA) || (spk_in_axon_type == DATA_END))) begin
                    axon_soma_we <= 1'b1;
                    axon_soma_waddr <= axon_soma_waddr + 1'b1;
                    axon_soma_wdata <= spk_in_axon_data;
                end
                else axon_soma_we <= 1'b0;
            end
            default : begin
                xl <= {NNW{1'b0}};
                xl_start_hold <= {NNW{1'b0}};
                yl <= {NNW{1'b0}};
                xl_end_hold <= {NNW{1'b0}};
                yl_end_hold <= {NNW{1'b0}};
                xw <= {NNW{1'b0}};
                xw_start_hold <= {NNW{1'b0}};
                yw <= {NNW{1'b0}};
                zw <= {NNW{1'b0}};
                axon_soma_we <= 1'b0;
                axon_soma_waddr <= {NNW{1'b0}};
                axon_soma_wdata <= {SW{1'b0}};
            end 
        endcase
    end
end

// analysis logic
assign xs = spk_in_axon_data[SW/3-1:0]; // TODO
assign ys = spk_in_axon_data[SW/3*2-1:SW/3];
assign zs = spk_in_axon_data[SW-1:SW/3*2];
assign stride = 1'b1 << stride_log;
assign axon_sd_wgt_addr = yw * x_k + xw + zw * xk_yk; // TODO
assign axon_sd_vm_addr = yl * x_out + xl;

always @( *) begin
    // x start
    if (xs + pad >= x_k - 1'b1) begin
        x_pre = xs + pad - x_k + 1'b1;
        xl_start = x_pre >> stride_log;
    end
    else begin
        x_pre = x_k - 1'b1 - xs - pad;
        xl_start = 0;
    end
    x_pre_stride = (x_pre << (NNW-stride_log)) >> (NNW-stride_log); // mod
    xw_start = x_k - 1'b1 - x_pre_stride;
    // x end
    if (xs + x_k <= x_in + pad) begin // x_post <= x_in + 2*pad - 1
        xl_end = (xs + pad) >> stride_log;
    end
    else begin
        xl_end = (x_in + pad + pad - x_k) >> stride_log;
    end
end

always @( *) begin
    // y start
    if (ys + pad >= y_k - 1'b1) begin
        y_pre = ys + pad - y_k + 1'b1;
        yl_start = y_pre >> stride_log;
    end
    else begin
        y_pre = y_k - 1'b1 - ys - pad;
        yl_start = 0;
    end
    y_pre_stride = (y_pre << (NNW-stride_log)) >> (NNW-stride_log); // mod
    yw_start = y_k - 1'b1 - y_pre_stride;
    // y end
    if (ys + y_k <= y_in + pad) begin // y_post <= y_in + 2*pad - 1
        yl_end = (ys + pad) >> stride_log;
    end
    else begin
        yl_end = (y_in + pad + pad - y_k) >> stride_log;
    end
end
    
endmodule