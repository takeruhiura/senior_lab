// I2C Address Scanner - Tests common LCD addresses and shows which one responds
module i2c_scanner (
    input wire clk,
    input wire rst,
    inout wire sda,
    output wire scl,
    output wire [15:0] led
);

    // Common I2C addresses for LCD modules
    reg [6:0] test_addr;
    reg [6:0] found_addr;
    reg addr_found;
    
    // I2C control
    reg i2c_ena;
    reg [7:0] i2c_data_wr;
    wire i2c_busy;
    wire i2c_ack_error;
    reg prev_busy;
    wire i2c_done = prev_busy & ~i2c_busy;
    
    reg [31:0] delay_cnt;
    reg [2:0] scan_state;
    
    localparam IDLE = 0, START_SCAN = 1, TEST_ADDR = 2, WAIT_RESULT = 3, FOUND = 4;
    
    // Test addresses: 0x27, 0x3F, 0x20, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E
    reg [6:0] addr_list [0:9];
    initial begin
        addr_list[0] = 7'h27;
        addr_list[1] = 7'h3F;
        addr_list[2] = 7'h20;
        addr_list[3] = 7'h38;
        addr_list[4] = 7'h39;
        addr_list[5] = 7'h3A;
        addr_list[6] = 7'h3B;
        addr_list[7] = 7'h3C;
        addr_list[8] = 7'h3D;
        addr_list[9] = 7'h3E;
    end
    
    reg [3:0] addr_index;
    
    // Debug LEDs
    // led[6:0] = found address (if found) or current test address
    // led[15] = address found indicator
    // led[14] = scanning indicator (blinks)
    // led[13] = ACK error indicator
    assign led[6:0] = addr_found ? found_addr : test_addr;
    assign led[15] = addr_found;
    assign led[14] = delay_cnt[23]; // Blink while scanning
    assign led[13] = i2c_ack_error;
    assign led[12] = i2c_busy;
    assign led[11] = (scan_state == TEST_ADDR);
    assign led[10:7] = addr_index;
    
    // I2C master
    i2c_master #(
        .input_clk(100_000_000), 
        .bus_clk(50_000)  // 50kHz
    ) i2c (
        .clk(clk),
        .reset_n(~rst),
        .ena(i2c_ena),
        .addr(test_addr),
        .rw(1'b0),  // Write
        .data_wr(8'h00),  // Send dummy data
        .busy(i2c_busy),
        .ack_error(i2c_ack_error),
        .sda(sda),
        .scl(scl)
    );
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_state <= IDLE;
            delay_cnt <= 0;
            addr_index <= 0;
            test_addr <= 7'h27;
            found_addr <= 0;
            addr_found <= 0;
            i2c_ena <= 0;
            prev_busy <= 0;
        end else begin
            prev_busy <= i2c_busy;
            i2c_ena <= 0;  // Default: don't start I2C
            
            case (scan_state)
                IDLE: begin
                    // Wait 1 second before starting scan
                    if (delay_cnt < 100_000_000) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        addr_index <= 0;
                        scan_state <= START_SCAN;
                    end
                end
                
                START_SCAN: begin
                    if (addr_found) begin
                        // Address already found, stay in FOUND state
                        scan_state <= FOUND;
                    end else if (addr_index < 10) begin
                        test_addr <= addr_list[addr_index];
                        delay_cnt <= 0;
                        scan_state <= TEST_ADDR;
                    end else begin
                        // Scanned all addresses, restart
                        addr_index <= 0;
                        delay_cnt <= 0;
                        scan_state <= IDLE;
                    end
                end
                
                TEST_ADDR: begin
                    if (!i2c_busy && !i2c_ena) begin
                        // Start I2C transaction to test address
                        i2c_ena <= 1;
                        scan_state <= WAIT_RESULT;
                    end
                end
                
                WAIT_RESULT: begin
                    if (i2c_done) begin
                        // I2C transaction complete, check result
                        if (!i2c_ack_error) begin
                            // No ACK error = device responded!
                            found_addr <= test_addr;
                            addr_found <= 1;
                            scan_state <= FOUND;
                        end else begin
                            // ACK error = no device at this address
                            addr_index <= addr_index + 1;
                            delay_cnt <= 0;
                            // Wait a bit before testing next address
                            if (delay_cnt < 10_000_000) begin  // 100ms
                                delay_cnt <= delay_cnt + 1;
                            end else begin
                                delay_cnt <= 0;
                                scan_state <= START_SCAN;
                            end
                        end
                    end
                end
                
                FOUND: begin
                    // Address found, display it on LEDs
                    // Keep scanning periodically to verify
                    if (delay_cnt < 200_000_000) begin  // 2 seconds
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        addr_found <= 0;
                        addr_index <= 0;
                        scan_state <= START_SCAN;
                    end
                end
            endcase
        end
    end

endmodule

// I2C Master Controller (same as in lcd_test_top.v)
module i2c_master #(
    parameter input_clk = 100_000_000,
    parameter bus_clk = 100_000
)(
    input clk,
    input reset_n,
    input ena,
    input [6:0] addr,
    input rw,
    input [7:0] data_wr,
    output reg busy,
    output reg ack_error,
    inout sda,
    output scl
);

    localparam divider = (input_clk/bus_clk)/4;
    
    localparam READY = 4'b0000, START = 4'b0001, COMMAND = 4'b0010,
               SLV_ACK1 = 4'b0011, WR = 4'b0100, SLV_ACK2 = 4'b0101,
               STOP = 4'b0110;
    
    reg [3:0] state;
    reg [15:0] count;
    reg scl_ena;
    reg sda_int;
    reg sda_ena_n;
    wire sda_in;
    reg [7:0] addr_rw;
    reg [7:0] data_tx;
    reg [3:0] bit_cnt;
    
    assign sda = sda_ena_n ? 1'bz : sda_int;
    assign sda_in = sda;
    assign scl = scl_ena ? (count < divider ? 1'b0 : 1'b1) : 1'b1;
    
    always @(posedge clk) begin
        if (!reset_n) begin
            count <= 0;
        end else begin
            if (count == divider*4 - 1) begin
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= READY;
            busy <= 1'b0;
            scl_ena <= 1'b0;
            sda_int <= 1'b1;
            sda_ena_n <= 1'b1;
            ack_error <= 1'b0;
            bit_cnt <= 7;
        end else begin
            if (count == divider - 1) begin
                case (state)
                    READY: begin
                        if (ena) begin
                            busy <= 1'b1;
                            addr_rw <= {addr, rw};
                            data_tx <= data_wr;
                            state <= START;
                        end else begin
                            busy <= 1'b0;
                            scl_ena <= 1'b0;
                        end
                    end
                    
                    START: begin
                        busy <= 1'b1;
                        scl_ena <= 1'b1;
                        sda_ena_n <= 1'b0;
                        sda_int <= 1'b0;
                        ack_error <= 1'b0;
                        state <= COMMAND;
                        bit_cnt <= 7;
                    end
                    
                    COMMAND: begin
                        sda_int <= addr_rw[bit_cnt];
                        if (bit_cnt == 0) begin
                            bit_cnt <= 7;
                            state <= SLV_ACK1;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                    
                    SLV_ACK1: begin
                        sda_ena_n <= 1'b1;
                        ack_error <= sda_in;
                        if (rw == 1'b0) begin
                            state <= WR;
                        end else begin
                            state <= STOP;
                        end
                    end
                    
                    WR: begin
                        sda_ena_n <= 1'b0;
                        sda_int <= data_tx[bit_cnt];
                        if (bit_cnt == 0) begin
                            bit_cnt <= 7;
                            state <= SLV_ACK2;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                    
                    SLV_ACK2: begin
                        sda_ena_n <= 1'b1;
                        state <= STOP;
                    end
                    
                    STOP: begin
                        busy <= 1'b0;
                        sda_ena_n <= 1'b0;
                        sda_int <= 1'b1;
                        state <= READY;
                    end
                endcase
            end
        end
    end

endmodule

