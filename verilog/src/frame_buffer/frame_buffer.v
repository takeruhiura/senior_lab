//////////////////////////////////////////////////////////////////////////////////
// Engineer: Adapted for Nexys4 DDR
// 
// Description: Dual-port Block RAM frame buffer for OV7670 camera
//              Write port: Camera capture (pclk domain)
//              Read port: VGA display (clk25 domain)
//              Size: 320x240 pixels = 76800 pixels = 153600 bytes
//              Using 12-bit RGB (4:4:4) = 921600 bits = 115200 bytes
//              Using 18-bit address (262144 locations)
//////////////////////////////////////////////////////////////////////////////////
module frame_buffer(
    // Write port (camera capture)
    input  wire        wr_clk,
    input  wire [17:0] wr_addr,
    input  wire [11:0] wr_data,
    input  wire        wr_en,
    
    // Read port (VGA display)
    input  wire        rd_clk,
    input  wire [17:0] rd_addr,
    output reg  [11:0] rd_data
);

    // Block RAM: 18-bit address, 12-bit data
    // 262144 x 12 bits = 3,145,728 bits = 384 KB
    reg [11:0] mem [0:262143];
    
    // Write port
    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
    // Read port
    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule

