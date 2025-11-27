`timescale 1ns / 1ps

module top(
    input clk,                 // 100 MHz Nexys4 DDR clock
    output [7:0] an,
    output [6:0] seg,
    output dp
);
    // -------------------------------------------------
    // Hardcoded digits for testing  (12345678)
    // Replace with your file-reader module in simulation
    // -------------------------------------------------
    wire [3:0] d1 = 4'd1;
    wire [3:0] d2 = 4'd2;
    wire [3:0] d3 = 4'd3;
    wire [3:0] d4 = 4'd4;
    wire [3:0] d5 = 4'd5;
    wire [3:0] d6 = 4'd6;
    wire [3:0] d7 = 4'd7;
    wire [3:0] d8 = 4'd8;

    // -------------------------------------------------
    // Clock divider for 1 kHz refresh
    // -------------------------------------------------
    wire clk_div;

    segClkDivider CLKDIV (
        .clk(clk),
        .clk_div(clk_div)
    );

    // -------------------------------------------------
    // 3-bit counter to select which digit is ON
    // -------------------------------------------------
    wire [2:0] sel;

    counter3bit CNT (
        .clk(clk_div),
        .rst(1'b0),
        .Q(sel)
    );

    // -------------------------------------------------
    // 8-input multiplexer → select current digit
    // -------------------------------------------------
    wire [3:0] selected_digit;

    mux4_4bus MUX (
        .I0(d1), .I1(d2), .I2(d3), .I3(d4),
        .I4(d5), .I5(d6), .I6(d7), .I7(d8),
        .Sel(sel),
        .Y(selected_digit)
    );

    // -------------------------------------------------
    // Seven-segment digit decoder
    // -------------------------------------------------
    sevensegdecoder SSD (
        .nIn(selected_digit),
        .ssOut(seg)
    );

    // -------------------------------------------------
    // Anode decoder (8 displays)
    // -------------------------------------------------
    decoder_3_8 DECODE8 (
        .I(sel),
        .an(an),
        .dp(dp)
    );

endmodule


// =====================================================
// Clock Divider (100 MHz → ~1 kHz)
// =====================================================
module segClkDivider(
    input clk,
    output reg clk_div = 0
);

    reg [16:0] cnt = 0;

    always @(posedge clk) begin
        if (cnt == 99999) begin
            cnt <= 0;
            clk_div <= ~clk_div;
        end else begin
            cnt <= cnt + 1;
        end
    end

endmodule
