module i2c_scanner(
    input  wire clk,          // 100 MHz clock
    output reg scl,
    inout  wire sda,
    output reg [15:0] leds
);

    // I2C lines
    reg sda_out = 1;
    reg sda_oe  = 0;   // 0 = input (released), 1 = driving
    assign sda = sda_oe ? sda_out : 1'bz;

    // Clock divider for slow I2C clock (~100 kHz)
    reg [9:0] div = 0;
    wire tick = (div == 999);
    always @(posedge clk) div <= tick ? 0 : div + 1;

    // Scanner
    reg [6:0] addr = 0;
    reg [3:0] bit_cnt = 0;
    reg [2:0] state = 0;
    reg ack = 0;

    always @(posedge clk) begin
        if (tick) begin
            case (state)
                0: begin
                    scl <= 1;
                    sda_oe <= 1;
                    sda_out <= 1;   // idle
                    bit_cnt <= 7;
                    state <= 1;
                end

                // START condition
                1: begin
                    sda_out <= 0;
                    scl <= 1;
                    state <= 2;
                end

                // Send 7-bit address + write bit
                2: begin
                    scl <= 0;
                    sda_out <= addr[bit_cnt];
                    if (bit_cnt == 0)
                        state <= 3;
                    else
                        bit_cnt <= bit_cnt - 1;
                end

                // R/W bit (0 = write)
                3: begin
                    scl <= 0;
                    sda_out <= 0;
                    state <= 4;
                end

                // ACK bit
                4: begin
                    scl <= 0;
                    sda_oe <= 0;  // release SDA
                    scl <= 1;
                    ack <= (sda == 0);
                    state <= 5;
                end

                // STOP + report
                5: begin
                    scl <= 0;
                    sda_oe <= 1;
                    sda_out <= 0;
                    scl <= 1;
                    sda_out <= 1;

                    if (ack)
                        leds[addr] <= 1;

                    addr <= addr + 1;
                    state <= 0;
                end
            endcase
        end
    end
endmodule
