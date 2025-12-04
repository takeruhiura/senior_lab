`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2025 07:55:35 PM
// Design Name: 
// Module Name: ov7670_capture
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//module ov7670_capture(
module ov7670_capture #(
    parameter IMG_W = 160,
    parameter IMG_H = 120
)(
    input  wire        pclk,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    input  wire        cfg_done,

    output reg         we,
    output reg [14:0]  waddr,
    output reg [7:0]   wdata,
    output reg         frame_done
);
    reg vsync_d = 1'b0;
    always @(posedge pclk) begin
        vsync_d <= vsync;
    end
    wire vsync_rising  = (vsync && !vsync_d);
    wire vsync_falling = (!vsync && vsync_d);

    reg [8:0] x = 9'd0;
    reg [8:0] y = 9'd0;
    reg capturing = 1'b0;

    always @(posedge pclk) begin
        frame_done <= 1'b0;
        we         <= 1'b0;

        if (!cfg_done) begin
            capturing <= 1'b0;
            x <= 0;
            y <= 0;
            waddr <= 0;
        end else begin
            if (vsync_rising) begin
                // start of frame
                capturing <= 1'b1;
                x <= 0;
                y <= 0;
                waddr <= 0;
            end

            if (vsync_falling) begin
                // end of frame
                capturing <= 1'b0;
                frame_done <= 1'b1;
            end

            if (capturing && href) begin
                if (x < IMG_W && y < IMG_H) begin
                    we    <= 1'b1;
                    wdata <= d;   // treat as grayscale
                    waddr <= y * IMG_W + x;
                    x <= x + 1'b1;
                end else begin
                    // ignore extra pixels in line
                end
            end else if (capturing && !href) begin
                // new line
                x <= 0;
                if (y < IMG_H-1)
                    y <= y + 1'b1;
            end
        end
    end

endmodule
