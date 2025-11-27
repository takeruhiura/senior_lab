//////////////////////////////////////////////////////////////////////////////////
// Engineer: Adapted for Nexys4 DDR
// 
// Description: Clock divider to generate 25MHz for VGA and camera XCLK
//              Input: 100MHz, Output: 25MHz (divide by 4)
//////////////////////////////////////////////////////////////////////////////////
module clock_divider(
    input  wire clk100mhz,
    output reg  clk25mhz,
    output reg  clk50mhz
);

    reg [1:0] counter25 = 2'b0;
    reg       counter50 = 1'b0;

    // Generate 25MHz clock (divide by 4)
    always @(posedge clk100mhz) begin
        if (counter25 == 2'b11) begin
            counter25 <= 2'b0;
            clk25mhz <= ~clk25mhz;
        end else begin
            counter25 <= counter25 + 1;
        end
    end
    
    // Generate 50MHz clock (divide by 2)
    always @(posedge clk100mhz) begin
        counter50 <= ~counter50;
        clk50mhz <= counter50;
    end

endmodule

