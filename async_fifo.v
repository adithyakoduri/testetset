

module async_fifo #(
    parameter DATA_WIDTH = 48,
    parameter ADDR_WIDTH = 10     // DEPTH = 1024
)(
    // Write Domain
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg                  full,

    // Read Domain
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] dout,
    output reg                  empty
);

localparam DEPTH = (1 << ADDR_WIDTH);

//--------------------------------------------------
// Memory
//--------------------------------------------------

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

//--------------------------------------------------
// Binary and Gray Pointers
//--------------------------------------------------

reg [ADDR_WIDTH:0] wr_ptr_bin;
reg [ADDR_WIDTH:0] wr_ptr_gray;

reg [ADDR_WIDTH:0] rd_ptr_bin;
reg [ADDR_WIDTH:0] rd_ptr_gray;

//--------------------------------------------------
// Next Pointer Logic
//--------------------------------------------------

wire [ADDR_WIDTH:0] wr_ptr_bin_next;
wire [ADDR_WIDTH:0] wr_ptr_gray_next;

wire [ADDR_WIDTH:0] rd_ptr_bin_next;
wire [ADDR_WIDTH:0] rd_ptr_gray_next;
wire                  full_next;
wire                  empty_next;
assign wr_ptr_bin_next  = wr_ptr_bin + (wr_en & ~full);
assign wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

assign rd_ptr_bin_next  = rd_ptr_bin + (rd_en & ~empty);
assign rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;

//--------------------------------------------------
// Synchronizers
//--------------------------------------------------

reg [ADDR_WIDTH:0] rd_ptr_gray_sync1;
reg [ADDR_WIDTH:0] rd_ptr_gray_sync2;

reg [ADDR_WIDTH:0] wr_ptr_gray_sync1;
reg [ADDR_WIDTH:0] wr_ptr_gray_sync2;
reg [ADDR_WIDTH:0] rd_ptr_bin_sync;


//--------------------------------------------------
// Read Pointer into Write Clock Domain
//--------------------------------------------------

always @(posedge wr_clk or negedge wr_rst_n)
begin
    if(!wr_rst_n)
    begin
        rd_ptr_gray_sync1 <= 'd0;
        rd_ptr_gray_sync2 <= 'd0;
    end
    else
    begin
        rd_ptr_gray_sync1 <= rd_ptr_gray;
        rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
end

//--------------------------------------------------
// Write Pointer into Read Clock Domain
//--------------------------------------------------

always @(posedge rd_clk or negedge rd_rst_n)
begin
    if(!rd_rst_n)
    begin
        wr_ptr_gray_sync1 <= 'd0;
        wr_ptr_gray_sync2 <= 'd0;
    end
    else
    begin
        wr_ptr_gray_sync1 <= wr_ptr_gray;
        wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
end

//--------------------------------------------------
// Full Logic
//--------------------------------------------------

assign full_next =
    (wr_ptr_gray_next ==
    {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
      rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

//--------------------------------------------------
// Empty Logic
//--------------------------------------------------

assign empty_next = (rd_ptr_gray == wr_ptr_gray_sync2);

//--------------------------------------------------
// Write Logic
//--------------------------------------------------

always @(posedge wr_clk or negedge wr_rst_n)
begin
    if(!wr_rst_n)
    begin
        wr_ptr_bin  <= 'd0;
        wr_ptr_gray <= 'd0;
         full        <= 1'b0;
    end
    else
    begin
            full <= full_next;
        if(wr_en && !full)
        begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;

            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end
end

//--------------------------------------------------
// Read Logic
//--------------------------------------------------

always @(posedge rd_clk or negedge rd_rst_n)
begin
    if(!rd_rst_n)
    begin
        rd_ptr_bin  <= 'd0;
        rd_ptr_gray <= 'd0;
        dout        <= 'd0;
        empty       <= 1'b1;
    end
    else
    begin
        empty <= empty_next;
        if(rd_en && !empty)
        begin
            dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end
end

endmodule