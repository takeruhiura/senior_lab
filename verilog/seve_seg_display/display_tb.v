`timescale 1ns / 1ps

module DigitToSeg_tb;

    // Inputs
    reg mclk;
    reg [3:0] in1, in2, in3, in4, in5, in6, in7, in8;

    // Outputs
    wire [7:0] an;
    wire [6:0] seg;
    wire dp;

    // Instantiate DUT (Device Under Test)
    DigitToSeg uut (
        .in1(in1),
        .in2(in2),
        .in3(in3),
        .in4(in4),
        .in5(in5),
        .in6(in6),
        .in7(in7),
        .in8(in8),
        .mclk(mclk),
        .an(an),
        .dp(dp),
        .seg(seg)
    );

    // Clock generation: 100 MHz (10ns period)
    always #5 mclk = ~mclk;

    initial begin
        // Initialize
        mclk = 0;

        // Assign values to display
        in1 = 4'hA; // A
        in2 = 4'hB; // B
        in3 = 4'hC; // C
        in4 = 4'hD; // D
        in5 = 4'h1; // 1
        in6 = 4'h2; // 2
        in7 = 4'h3; // 3
        in8 = 4'h4; // 4

        // Let simulation run
        $display("Simulation started");
        #200000;   // enough time for many multiplex cycles

        $display("Simulation finished");
        $stop;
    end

    // Optional: Monitor output to see activity
    initial begin
        $monitor("Time=%0t  AN=%b  SEG=%b  DP=%b", $time, an, seg, dp);
    end

endmodule
