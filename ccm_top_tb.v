`timescale 1ns/1ps

module ccm_top_tb;

//====================================================
// Clocks / Reset
//====================================================

reg pixel_clk;
reg ccm_clk;

reg pixel_rst_n;
reg ccm_rst_n;

initial pixel_clk = 0;
always #5 pixel_clk = ~pixel_clk;      // 100 MHz

initial ccm_clk = 0;
always #7 ccm_clk = ~ccm_clk;          // Different clock to test async FIFO

//====================================================
// DUT Inputs
//====================================================

reg         i_valid;
reg [15:0]  i_r;
reg [15:0]  i_g;
reg [15:0]  i_b;

wire        fifo_full;

reg         coeff_wr;
reg [3:0]   coeff_addr;
reg signed [15:0] coeff_data;

//====================================================
// DUT Outputs
//====================================================

wire        o_valid;
wire [15:0] o_r;
wire [15:0] o_g;
wire [15:0] o_b;

//====================================================
// DUT
//====================================================

ccm_top dut
(
    .pixel_clk   (pixel_clk),
    .pixel_rst_n (pixel_rst_n),

    .i_valid     (i_valid),
    .i_r         (i_r),
    .i_g         (i_g),
    .i_b         (i_b),

    .fifo_full   (fifo_full),

    .ccm_clk     (ccm_clk),
    .ccm_rst_n   (ccm_rst_n),

    .coeff_wr    (coeff_wr),
    .coeff_addr  (coeff_addr),
    .coeff_data  (coeff_data),

    .o_valid     (o_valid),
    .o_r         (o_r),
    .o_g         (o_g),
    .o_b         (o_b)
);

//====================================================
// VCD
//====================================================

initial
begin
    $dumpfile("ccm.vcd");
    $dumpvars(0, ccm_top_tb);
end

//====================================================
// File Handles
//====================================================

integer fin;
integer fout;

integer status;

reg [15:0] file_r;
reg [15:0] file_g;
reg [15:0] file_b;

integer pixel_count;
integer output_count;

//====================================================
// Coefficient Write Task
//====================================================

task write_coeff;
input [3:0] addr;
input signed [15:0] data;
begin

    @(posedge ccm_clk);

    coeff_wr   <= 1'b1;
    coeff_addr <= addr;
    coeff_data <= data;

    @(posedge ccm_clk);

    coeff_wr   <= 1'b0;
    coeff_addr <= 0;
    coeff_data <= 0;

    $display("[%0t] COEFF[%0d] = %0d",
             $time, addr, data);

end
endtask

//====================================================
// Reset
//====================================================

initial
begin

    pixel_rst_n = 0;
    ccm_rst_n   = 0;

    i_valid     = 0;
    i_r         = 0;
    i_g         = 0;
    i_b         = 0;

    coeff_wr    = 0;
    coeff_addr  = 0;
    coeff_data  = 0;

    pixel_count = 0;
    output_count = 0;

    repeat(10) @(posedge pixel_clk);

    pixel_rst_n = 1;
    ccm_rst_n   = 1;

end

//====================================================
// Main Test
//====================================================

initial
begin

    wait(pixel_rst_n);
    wait(ccm_rst_n);

    //------------------------------------------------
    // Program CCM Coefficients
    //------------------------------------------------

    write_coeff(0,  2);
    write_coeff(1, -1);
    write_coeff(2,  1);

    write_coeff(3,  1);
    write_coeff(4,  2);
    write_coeff(5,  0);

    write_coeff(6,  0);
    write_coeff(7,  1);
    write_coeff(8,  2);

    $display("\n================================");
    $display(" CCM COEFFICIENTS PROGRAMMED");
    $display("================================\n");

    //------------------------------------------------
    // Open Files
    //------------------------------------------------

    fin = $fopen("pixels.txt", "r");

    if(fin == 0)
    begin
        $display("ERROR: pixels.txt not found");
        $finish;
    end

    fout = $fopen("out_pixels.txt", "w");

    //------------------------------------------------
    // Feed Pixels
    //------------------------------------------------

    while(!$feof(fin))
begin
     $display("Reading next pixel...");

    status = $fscanf(fin,
                     "%d %d %d\n",
                     file_r,
                     file_g,
                     file_b);
    $display("status=%0d r=%0d g=%0d b=%0d",
         status,
         file_r,
         file_g,
         file_b);
    if(status == 3)
    begin
        if(fifo_full)
            $display("[%0t] FIFO FULL ASSERTED", $time);
        @(posedge pixel_clk);
        
        while(fifo_full)
        begin
            $display("[%0t] FIFO FULL", $time);
            @(posedge pixel_clk);
        end

        i_valid <= 1'b1;
        i_r     <= file_r;
        i_g     <= file_g;
        i_b     <= file_b;

        pixel_count = pixel_count + 1;

        $display("[%0t] INPUT PIXEL %0d : R=%0d G=%0d B=%0d",
                 $time,
                 pixel_count,
                 file_r,
                 file_g,
                 file_b);

        @(posedge pixel_clk);

        i_valid <= 1'b0;

    end

end

    $fclose(fin);

    //------------------------------------------------
    // Wait for outputs
    //------------------------------------------------

    #5000;

    $display("\n================================");
    $display(" Pixels Sent     = %0d", pixel_count);
    $display(" Pixels Received = %0d", output_count);
    $display("================================\n");

    $fclose(fout);

    $finish;

end

//====================================================
// Output Monitor
//====================================================
always @(posedge ccm_clk)
begin
    if(ccm_rst_n)
    begin
        $display("[%0t] in=%0d out=%0d full=%0b empty=%0b rd_en=%0b o_valid=%0b",
                 $time,
                 pixel_count,
                 output_count,
                 fifo_full,
                 dut.fifo_empty,
                 dut.fifo_rd_en,
                 o_valid);
    end
end
always @(posedge ccm_clk)
begin
    if(ccm_rst_n)
    begin
        $display("[%0t] state=%0d empty=%0b rd_en=%0b",
                 $time,
                 dut.u_ccm_engine.state,
                 dut.fifo_empty,
                 dut.fifo_rd_en);
    end
end
always @(posedge ccm_clk)
begin
    if(ccm_rst_n)
    begin
        if(dut.fifo_rd_en || o_valid)
        begin
            $display("[%0t] empty=%0b rd_en=%0b o_valid=%0b out=%0d",
                     $time,
                     dut.fifo_empty,
                     dut.fifo_rd_en,
                     o_valid,
                     output_count);
        end
    end
end
always @(posedge ccm_clk)
begin

    if(o_valid)
    begin

        output_count = output_count + 1;

        $display("[%0t] OUTPUT PIXEL %0d : R=%0d G=%0d B=%0d",
                 $time,
                 output_count,
                 o_r,
                 o_g,
                 o_b);

        $fwrite(fout,
                "%0d %0d %0d\n",
                o_r,
                o_g,
                o_b);

    end

end

//====================================================
// FIFO Debug
//====================================================

always @(posedge pixel_clk)
begin

    if(i_valid)
    begin
        $display("[%0t] FIFO WRITE : R=%0d G=%0d B=%0d",
                 $time,
                 i_r,
                 i_g,
                 i_b);
    end

end

//====================================================
// Timeout Protection
//====================================================

initial
begin

    #100000;

    $display("TIMEOUT");
    $finish;

end

endmodule