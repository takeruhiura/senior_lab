//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mike Field <hamster@snap.net.nz>
// 
// Description: Generate analog 640x480 VGA, double-doublescanned from 19200 bytes of RAM
// Adapted for Nexys4 DDR
//////////////////////////////////////////////////////////////////////////////////
module ov7670_vga(
    input  wire        clk25,
    output reg  [3:0]  vga_red,
    output reg  [3:0]  vga_green,
    output reg  [3:0]  vga_blue,
    output reg         vga_hsync,
    output reg         vga_vsync,
    output reg  [17:0] frame_addr,
    input  wire [11:0] frame_pixel
);

    // Timing constants
    parameter hRez       = 640;
    parameter hStartSync = 656;  // 640+16
    parameter hEndSync   = 752;  // 640+16+96
    parameter hMaxCount  = 800;
    
    parameter vRez       = 480;
    parameter vStartSync = 490;  // 480+10
    parameter vEndSync   = 492;   // 480+10+2
    parameter vMaxCount  = 525;   // 480+10+2+33
    
    parameter hsync_active = 1'b0;
    parameter vsync_active = 1'b0;

    reg [9:0] hCounter = 10'h0;
    reg [9:0] vCounter = 10'h0;
    reg [18:0] address = 19'h0;
    reg blank = 1'b1;

    always @(posedge clk25) begin
        // Count the lines and rows      
        if (hCounter == hMaxCount-1) begin
            hCounter <= 10'h0;
            if (vCounter == vMaxCount-1) begin
                vCounter <= 10'h0;
            end else begin
                vCounter <= vCounter + 1;
            end
        end else begin
            hCounter <= hCounter + 1;
        end

        if (blank == 1'b0) begin
            vga_red   <= frame_pixel[11:8];
            vga_green <= frame_pixel[7:4];
            vga_blue  <= frame_pixel[3:0];
        end else begin
            vga_red   <= 4'h0;
            vga_green <= 4'h0;
            vga_blue  <= 4'h0;
        end

        if (vCounter >= vRez) begin
            address <= 19'h0;
            blank <= 1'b1;
        end else begin
            if (hCounter < 640) begin
                blank <= 1'b0;
                address <= address + 1;
            end else begin
                blank <= 1'b1;
            end
        end

        // Are we in the hSync pulse?
        if (hCounter > hStartSync && hCounter <= hEndSync) begin
            vga_hsync <= hsync_active;
        end else begin
            vga_hsync <= ~hsync_active;
        end

        // Are we in the vSync pulse?
        if (vCounter >= vStartSync && vCounter < vEndSync) begin
            vga_vsync <= vsync_active;
        end else begin
            vga_vsync <= ~vsync_active;
        end
        
        frame_addr <= address[18:1];
    end
endmodule

