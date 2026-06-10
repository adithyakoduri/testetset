
`timescale 1ns/1ps

module ccm_top
(
    //--------------------------------------------------
    // Pixel Domain
    //--------------------------------------------------
    input  wire        pixel_clk,
    input  wire        pixel_rst_n,

    input  wire        i_valid,
    input  wire [15:0] i_r,
    input  wire [15:0] i_g,
    input  wire [15:0] i_b,

    output wire        fifo_full,

    //--------------------------------------------------
    // CCM Domain
    //--------------------------------------------------
    input  wire        ccm_clk,
    input  wire        ccm_rst_n,

    //--------------------------------------------------
    // Coefficients
    //--------------------------------------------------
    input  wire        coeff_wr,
    input  wire [3:0]  coeff_addr,
    input  wire signed [15:0] coeff_data,

    //--------------------------------------------------
    // Output
    //--------------------------------------------------
    output wire        o_valid,
    output wire [15:0] o_r,
    output wire [15:0] o_g,
    output wire [15:0] o_b
);

    //--------------------------------------------------
    // FIFO Signals
    //--------------------------------------------------

    wire [47:0] fifo_din;
    wire [47:0] fifo_dout;

    wire fifo_empty;
    wire fifo_rd_en;

    assign fifo_din = {i_r, i_g, i_b};

    //--------------------------------------------------
    // Async FIFO
    //--------------------------------------------------

    async_fifo #(
        .DATA_WIDTH (48),
        .ADDR_WIDTH (10)
    ) u_async_fifo (
        .wr_clk   (pixel_clk),
        .wr_rst_n (pixel_rst_n),
        .wr_en    (i_valid),
        .din      (fifo_din),
        .full     (fifo_full),

        .rd_clk   (ccm_clk),
        .rd_rst_n (ccm_rst_n),
        .rd_en    (fifo_rd_en),
        .dout     (fifo_dout),
        .empty    (fifo_empty)
    );

    //--------------------------------------------------
    // CCM Engine
    //--------------------------------------------------

    ccm_engine u_ccm_engine (
        .clk        (ccm_clk),
        .rst_n      (ccm_rst_n),

        .fifo_empty (fifo_empty),
        .fifo_rd_en (fifo_rd_en),
        .fifo_dout  (fifo_dout),

        .coeff_wr   (coeff_wr),
        .coeff_addr (coeff_addr),
        .coeff_data (coeff_data),

        .o_valid    (o_valid),
        .o_r        (o_r),
        .o_g        (o_g),
        .o_b        (o_b)
    );

endmodule