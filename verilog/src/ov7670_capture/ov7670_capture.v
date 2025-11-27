//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mike Field <hamster@snap.net.nz>
// 
// Description: Captures the pixels coming from the OV7670 camera and 
//              Stores them in block RAM
// Adapted for Nexys4 DDR
//////////////////////////////////////////////////////////////////////////////////
module ov7670_capture(
    input  wire        pclk,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    output reg  [17:0] addr,
    output reg  [11:0] dout,
    output reg         we
);

    reg [15:0] d_latch = 16'h0;
    reg [18:0] address = 19'h0;
    reg [18:0] address_next = 19'h0;
    reg [1:0]  wr_hold = 2'b0;
    
    always @(posedge pclk) begin
        // This is a bit tricky href starts a pixel transfer that takes 3 cycles
        //        Input   | state after clock tick   
        //         href   | wr_hold    d_latch           d                 we address  address_next
        // cycle -1  x    |    xx      xxxxxxxxxxxxxxxx  xxxxxxxxxxxxxxxx  x   xxxx     xxxx
        // cycle 0   1    |    x1      xxxxxxxxRRRRRGGG  xxxxxxxxxxxxxxxx  x   xxxx     addr
        // cycle 1   0    |    10      RRRRRGGGGGGBBBBB  xxxxxxxxRRRRRGGG  x   addr     addr
        // cycle 2   x    |    0x      GGGBBBBBxxxxxxxx  RRRRRGGGGGGBBBBB  1   addr     addr+1

        if (vsync == 1'b1) begin
            address <= 19'h0;
            address_next <= 19'h0;
            wr_hold <= 2'b0;
        end else begin
            // This should be a different order, but seems to be GRB!
            dout    <= {d_latch[15:12], d_latch[10:7], d_latch[4:1]}; 
            addr    <= address_next[18:1];
            we      <= wr_hold[1];
            wr_hold <= {wr_hold[0], (href & ~wr_hold[0])};
            d_latch <= {d_latch[7:0], d};

            if (wr_hold[1] == 1'b1) begin
                address_next <= address_next + 1;
            end
        end
        address <= address_next;
    end
endmodule

