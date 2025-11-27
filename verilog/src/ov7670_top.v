//////////////////////////////////////////////////////////////////////////////////
// Engineer: Adapted for Nexys4 DDR
// 
// Description: Top-level module for OV7670 camera to VGA display on Nexys4 DDR
//              Based on: https://github.com/bwang40/OV7670_NEXYS4DDR_HDL
// 
// Connections:
// - OV7670 camera on PMOD JC and JD
// - VGA output to VGA connector
// - Clock: 100MHz system clock
//////////////////////////////////////////////////////////////////////////////////
module ov7670_top(
    // System Clock
    input  wire        CLK100MHZ,
    
    // OV7670 Camera Interface (PMOD JC and JD)
    output wire        ov7670_scl,      // I2C Clock (JC[1])
    inout  wire        ov7670_sda,      // I2C Data (JC[2])
    input  wire        ov7670_vs,       // VSYNC (JC[3])
    input  wire        ov7670_hs,       // HSYNC (JC[4])
    input  wire        ov7670_plk,      // Pixel Clock (JC[7])
    output wire        ov7670_xlk,      // XCLK (JC[8])
    input  wire [7:0]  ov7670_data,     // Pixel Data (JC[9:10], JD[1:4,7:8])
    output wire        ov7670_rei,      // RESET (JD[9])
    output wire        ov7670_pwdn,     // Power Down (JD[10])
    
    // VGA Output
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    
    // Debug/Control
    input  wire        BTNC             // Center button for resend config
);

    // Clock signals
    wire clk25mhz;
    wire clk50mhz;
    
    // OV7670 Controller signals
    wire config_finished;
    wire sioc;
    wire siod;
    wire reset;
    wire pwdn;
    wire xclk;
    
    // OV7670 Capture signals
    wire [17:0] capture_addr;
    wire [11:0] capture_data;
    wire        capture_we;
    
    // VGA signals
    wire [17:0] vga_addr;
    wire [11:0] vga_data;
    
    // Frame buffer signals
    wire [17:0] frame_wr_addr;
    wire [11:0] frame_wr_data;
    wire        frame_wr_en;
    wire [17:0] frame_rd_addr;
    wire [11:0] frame_rd_data;
    
    // Clock divider: 100MHz -> 25MHz and 50MHz
    clock_divider u_clock_divider(
        .clk100mhz (CLK100MHZ),
        .clk25mhz  (clk25mhz),
        .clk50mhz  (clk50mhz)
    );
    
    // OV7670 Controller: I2C configuration
    ov7670_controller u_ov7670_controller(
        .clk            (clk50mhz),
        .resend         (BTNC),
        .config_finished(config_finished),
        .sioc           (sioc),
        .siod           (siod),
        .reset          (reset),
        .pwdn           (pwdn),
        .xclk           (xclk)
    );
    
    // OV7670 Capture: Capture pixels from camera
    ov7670_capture u_ov7670_capture(
        .pclk   (ov7670_plk),
        .vsync  (ov7670_vs),
        .href   (ov7670_hs),
        .d      (ov7670_data),
        .addr   (capture_addr),
        .dout   (capture_data),
        .we     (capture_we)
    );
    
    // Frame Buffer: Dual-port BRAM
    frame_buffer u_frame_buffer(
        .wr_clk  (ov7670_plk),
        .wr_addr (capture_addr),
        .wr_data (capture_data),
        .wr_en   (capture_we),
        .rd_clk  (clk25mhz),
        .rd_addr (vga_addr),
        .rd_data (vga_data)
    );
    
    // VGA Controller: Display frame buffer on VGA
    ov7670_vga u_ov7670_vga(
        .clk25      (clk25mhz),
        .vga_red    (VGA_R),
        .vga_green  (VGA_G),
        .vga_blue   (VGA_B),
        .vga_hsync  (VGA_HS),
        .vga_vsync  (VGA_VS),
        .frame_addr (vga_addr),
        .frame_pixel(vga_data)
    );
    
    // Connect OV7670 signals
    assign ov7670_scl  = sioc;
    assign ov7670_sda  = siod;
    assign ov7670_xlk  = xclk;
    assign ov7670_rei  = reset;
    assign ov7670_pwdn = pwdn;

endmodule

