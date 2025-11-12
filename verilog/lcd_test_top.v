// I2C Scanner + LCD Controller - Auto-detects LCD address
module lcd_test_top (
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button
    inout wire sda,           // I2C data line
    output wire scl,          // I2C clock line
    output wire [15:0] led    // Debug LEDs
);

    // I2C LCD address to use (will scan through these)
    reg [6:0] current_addr;
    reg addr_found;
    
    // State machine
    localparam SCAN = 0, INIT = 1, WRITE = 2, DONE = 3;
    reg [1:0] state;
    reg [31:0] delay_cnt;
    reg [7:0] cmd_idx;
    reg [7:0] char_idx;
    reg [1:0] scan_idx;
    
    // I2C control
    reg i2c_ena;
    reg [7:0] i2c_data_wr;
    wire i2c_busy;
    wire i2c_ack_error;
    reg prev_busy;
    
    // LCD data to send via I2C
    reg [7:0] lcd_byte;
    reg [3:0] lcd_step;
    reg lcd_rs;
    
    // Message
    reg [7:0] message [0:31];
    initial begin
        message[0]="H"; message[1]="e"; message[2]="l"; message[3]="l";
        message[4]="o"; message[5]=" "; message[6]="f"; message[7]="r";
        message[8]="o"; message[9]="m"; message[10]=" "; message[11]="F";
        message[12]="P"; message[13]="G"; message[14]="A"; message[15]="!";
        message[16]="A"; message[17]="d"; message[18]="d"; message[19]="r";
        message[20]=":"; message[21]=" "; message[22]="0"; message[23]="x";
        message[24]="?"; message[25]="?"; message[26]=" "; message[27]=" ";
        message[28]=" "; message[29]=" "; message[30]=" "; message[31]=" ";
    end
    
    // Init commands
    reg [7:0] init_cmd [0:6];
    initial begin
        init_cmd[0] = 8'h33; init_cmd[1] = 8'h32; init_cmd[2] = 8'h28;
        init_cmd[3] = 8'h0C; init_cmd[4] = 8'h06; init_cmd[5] = 8'h01;
        init_cmd[6] = 8'h80;
    end
    
    // Debug LEDs - SHOWS ADDRESS DETECTION
    assign led[1:0] = state;
    assign led[3:2] = scan_idx;
    assign led[4] = addr_found;
    assign led[11:5] = current_addr;  // Shows detected I2C address
    assign led[12] = i2c_ena;
    assign led[13] = prev_busy;
    assign led[14] = i2c_busy;
    assign led[15] = i2c_ack_error;
    
    wire i2c_done = prev_busy & ~i2c_busy;
    
    // Convert address to ASCII hex for display
    function [7:0] hex_to_ascii;
        input [3:0] hex;
        begin
            hex_to_ascii = (hex < 10) ? (8'h30 + hex) : (8'h37 + hex);
        end
    endfunction
    
    // Get address based on scan index
    function [6:0] get_scan_addr;
        input [1:0] idx;
        begin
            case (idx)
                2'd0: get_scan_addr = 7'h20;
                2'd1: get_scan_addr = 7'h27;
                2'd2: get_scan_addr = 7'h3F;
                default: get_scan_addr = 7'h3F;
            endcase
        end
    endfunction
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SCAN;
            delay_cnt <= 0;
            cmd_idx <= 0;
            char_idx <= 0;
            scan_idx <= 0;
            i2c_ena <= 0;
            lcd_step <= 0;
            prev_busy <= 0;
            lcd_rs <= 0;
            addr_found <= 0;
            current_addr <= 7'h3F;
        end else begin
            prev_busy <= i2c_busy;
            
            case (state)
                SCAN: begin
                    case (lcd_step)
                        0: begin // Initial delay
                            if (delay_cnt < 50_000_000) // 500ms
                                delay_cnt <= delay_cnt + 1;
                            else begin
                                delay_cnt <= 0;
                                current_addr <= get_scan_addr(scan_idx);
                                lcd_step <= 1;
                            end
                        end
                        
                        1: begin // Send test byte to current address
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= 8'h00;
                                i2c_ena <= 1;
                                lcd_step <= 2;
                            end
                        end
                        
                        2: begin // Wait for I2C transaction
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 3;
                        end
                        
                        3: begin // Check if ACK received
                            if (delay_cnt < 10_000_000) // 100ms delay
                                delay_cnt <= delay_cnt + 1;
                            else begin
                                delay_cnt <= 0;
                                if (!i2c_ack_error) begin
                                    // Found it!
                                    addr_found <= 1;
                                    // Update message with hex address
                                    message[24] <= hex_to_ascii({1'b0, current_addr[6:4]});
                                    message[25] <= hex_to_ascii(current_addr[3:0]);
                                    state <= INIT;
                                    lcd_step <= 0;
                                    cmd_idx <= 0;
                                end else if (scan_idx < 2) begin
                                    // Try next address
                                    scan_idx <= scan_idx + 1;
                                    lcd_step <= 0;
                                end else begin
                                    // No device found - blink LEDs
                                    state <= DONE;
                                    lcd_step <= 0;
                                end
                            end
                        end
                    endcase
                end
                
                INIT: begin
                    case (lcd_step)
                        0: begin
                            if (cmd_idx < 7) begin
                                lcd_byte <= init_cmd[cmd_idx];
                                lcd_rs <= 0;
                                lcd_step <= 1;
                            end else begin
                                state <= WRITE;
                                cmd_idx <= 0;
                                char_idx <= 0;
                                lcd_step <= 0;
                            end
                        end
                        
                        1: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b1, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 2;
                            end
                        end
                        
                        2: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 3;
                        end
                        
                        3: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b0, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 4;
                            end
                        end
                        
                        4: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 5;
                        end
                        
                        5: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b1, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 6;
                            end
                        end
                        
                        6: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 7;
                        end
                        
                        7: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b0, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 8;
                            end
                        end
                        
                        8: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 9;
                        end
                        
                        9: begin
                            if (delay_cnt < 500_000)
                                delay_cnt <= delay_cnt + 1;
                            else begin
                                delay_cnt <= 0;
                                cmd_idx <= cmd_idx + 1;
                                lcd_step <= 0;
                            end
                        end
                    endcase
                end
                
                WRITE: begin
                    case (lcd_step)
                        0: begin
                            if (char_idx == 16) begin
                                lcd_byte <= 8'hC0;
                                lcd_rs <= 0;
                                lcd_step <= 1;
                            end else if (char_idx < 32) begin
                                lcd_byte <= message[char_idx];
                                lcd_rs <= 1;
                                lcd_step <= 1;
                            end else begin
                                state <= DONE;
                            end
                        end
                        
                        1: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b1, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 2;
                            end
                        end
                        
                        2: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 3;
                        end
                        
                        3: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b0, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 4;
                            end
                        end
                        
                        4: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 5;
                        end
                        
                        5: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b1, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 6;
                            end
                        end
                        
                        6: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 7;
                        end
                        
                        7: begin
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b0, 1'b0, lcd_rs};
                                i2c_ena <= 1;
                                lcd_step <= 8;
                            end
                        end
                        
                        8: begin
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) begin
                                char_idx <= char_idx + 1;
                                lcd_step <= 0;
                            end
                        end
                    endcase
                end
                
                DONE: begin
                    // If address found, stay here. Otherwise blink error pattern
                    if (!addr_found) begin
                        if (delay_cnt < 50_000_000)
                            delay_cnt <= delay_cnt + 1;
                        else
                            delay_cnt <= 0;
                    end
                end
            endcase
        end
    end
    
    // I2C master with dynamic address
    i2c_master #(
        .input_clk(100_000_000), 
        .bus_clk(100_000)
    ) i2c (
        .clk(clk),
        .reset_n(~rst),
        .ena(i2c_ena),
        .addr(current_addr),
        .rw(1'b0),
        .data_wr(i2c_data_wr),
        .busy(i2c_busy),
        .ack_error(i2c_ack_error),
        .sda(sda),
        .scl(scl)
    );

endmodule

// I2C Master Controller
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
    
    localparam READY = 0, START = 1, COMMAND = 2, SLV_ACK1 = 3;
    localparam WR = 4, SLV_ACK2 = 5, STOP = 6;
    
    reg [2:0] state;
    reg [15:0] count;
    reg scl_clk;
    reg scl_ena;
    reg sda_int;
    reg sda_ena_n;
    reg [7:0] addr_rw;
    reg [7:0] data_tx;
    reg [2:0] bit_cnt;
    wire sda_in;
    
    assign scl = (scl_ena == 1'b0) ? 1'b1 : scl_clk;
    assign sda = (sda_ena_n == 1'b0) ? sda_int : 1'bz;
    assign sda_in = sda;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 0;
            scl_clk <= 1'b1;
        end else begin
            if (count == divider - 1) begin
                count <= 0;
                scl_clk <= ~scl_clk;
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
                        ack_error <= sda_in;  // If high, no ACK
                        if (rw == 1'b0) begin
                            state <= WR;
                        end else begin
                            state <= STOP;
                        end
                    end
                    
                    WR: begin
                        busy <= 1'b1;
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
