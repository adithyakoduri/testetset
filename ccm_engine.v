`timescale 1ns/1ps

module ccm_engine
(
    input  wire        clk,
    input  wire        rst_n,

    //--------------------------------------------------
    // FIFO Interface
    //--------------------------------------------------
    input  wire        fifo_empty,
    output reg         fifo_rd_en,
    input  wire [47:0] fifo_dout,

    //--------------------------------------------------
    // Coefficient Interface
    //--------------------------------------------------
    input  wire        coeff_wr,
    input  wire [3:0]  coeff_addr,
    input  wire signed [15:0] coeff_data,

    //--------------------------------------------------
    // Output Pixel
    //--------------------------------------------------
    output reg         o_valid,
    output reg [15:0]  o_r,
    output reg [15:0]  o_g,
    output reg [15:0]  o_b
);


//====================================================
// Coefficient Memory
//====================================================

reg signed [15:0] coeff_mem [0:8];

integer i;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        for(i=0;i<9;i=i+1)
            coeff_mem[i] <= 16'sd0;
    end
    else if(coeff_wr)
    begin
        coeff_mem[coeff_addr] <= coeff_data;
    end
end


//====================================================
// State Machine
//====================================================

localparam IDLE      = 3'd0;
localparam ROUT_MUL  = 3'd1;
localparam GOUT_MUL  = 3'd2;
localparam BOUT_MUL  = 3'd3;
localparam WRITE_OUT = 3'd4;

reg [2:0] state;


//====================================================
// Pixel Registers
//====================================================

reg [15:0] r_reg;
reg [15:0] g_reg;
reg [15:0] b_reg;


//====================================================
// Partial Products
//====================================================

reg signed [31:0] r_p0;
reg signed [31:0] r_p1;
reg signed [31:0] r_p2;

reg signed [31:0] g_p0;
reg signed [31:0] g_p1;
reg signed [31:0] g_p2;

reg signed [31:0] b_p0;
reg signed [31:0] b_p1;
reg signed [31:0] b_p2;


//====================================================
// Accumulators
//====================================================

reg signed [35:0] r_acc;
reg signed [35:0] g_acc;
reg signed [35:0] b_acc;


//====================================================
// Saturation Function
//====================================================

function [15:0] sat16;
input signed [35:0] value;

begin
    if(value < 0)
        sat16 = 16'd0;
    else if(value > 36'sd65535)
        sat16 = 16'hFFFF;
    else
        sat16 = value[15:0];
end
endfunction


//====================================================
// Main FSM
//====================================================

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        state      <= IDLE;

        fifo_rd_en <= 1'b0;

        r_reg      <= 16'd0;
        g_reg      <= 16'd0;
        b_reg      <= 16'd0;

        r_acc      <= 36'd0;
        g_acc      <= 36'd0;
        b_acc      <= 36'd0;

        o_valid    <= 1'b0;
        o_r        <= 16'd0;
        o_g        <= 16'd0;
        o_b        <= 16'd0;
    end
    else
    begin

        fifo_rd_en <= 1'b0;
        o_valid    <= 1'b0;

        case(state)

        //--------------------------------------------------
        // IDLE
        //--------------------------------------------------

        IDLE:
        begin
            if(!fifo_empty)
            begin
            $display("[%0t] ENGINE READ REQUEST", $time);
                fifo_rd_en <= 1'b1;

                r_reg <= fifo_dout[47:32];
                g_reg <= fifo_dout[31:16];
                b_reg <= fifo_dout[15:0];

                state <= ROUT_MUL;
            end
        end

        //--------------------------------------------------
        // ROUT
        //--------------------------------------------------

        ROUT_MUL:
        begin
            r_p0 <= $signed({1'b0,r_reg}) * coeff_mem[0];
            r_p1 <= $signed({1'b0,g_reg}) * coeff_mem[1];
            r_p2 <= $signed({1'b0,b_reg}) * coeff_mem[2];

            state <= GOUT_MUL;
        end

        //--------------------------------------------------
        // GOUT
        //--------------------------------------------------

        GOUT_MUL:
        begin

            g_p0 <= $signed({1'b0,r_reg}) * coeff_mem[3];
            g_p1 <= $signed({1'b0,g_reg}) * coeff_mem[4];
            g_p2 <= $signed({1'b0,b_reg}) * coeff_mem[5];

            r_acc <= r_p0 + r_p1 + r_p2;

            state <= BOUT_MUL;
        end

        //--------------------------------------------------
        // BOUT
        //--------------------------------------------------

        BOUT_MUL:
        begin

            b_p0 <= $signed({1'b0,r_reg}) * coeff_mem[6];
            b_p1 <= $signed({1'b0,g_reg}) * coeff_mem[7];
            b_p2 <= $signed({1'b0,b_reg}) * coeff_mem[8];

            g_acc <= g_p0 + g_p1 + g_p2;

            state <= WRITE_OUT;
        end

        //--------------------------------------------------
        // OUTPUT
        //--------------------------------------------------

        WRITE_OUT:
        begin

            b_acc <= b_p0 + b_p1 + b_p2;

            o_r <= sat16(r_acc);
            o_g <= sat16(g_acc);
            o_b <= sat16(b_p0 + b_p1 + b_p2);

            o_valid <= 1'b1;

            state <= IDLE;
        end

        default:
            state <= IDLE;

        endcase
    end
end

endmodule