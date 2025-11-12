// Top module for I2C LCD 20x4 display
module lcd_i2c_top (
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button
    inout wire sda,           // I2C data line
    output wire scl,          // I2C clock line
    output wire [15:0] led    // Debug LEDs
);

    // I2C LCD address
    localparam I2C_ADDR = 7'h3F;
    
    // State machine
    localparam IDLE = 0, INIT = 1, WRITE = 2, DONE = 3;
    reg [1:0] state;
    reg [31:0] delay_cnt;
    reg [7:0] cmd_idx;
    reg [7:0] char_idx;
    
    // I2C control
    reg i2c_ena;
    reg [7:0] i2c_data_wr;
    wire i2c_busy;
    wire i2c_ack_error;
    reg prev_busy;
    
    // LCD data to send via I2C (includes enable pulses)
    reg [7:0] lcd_byte;
    reg [3:0] lcd_step;
    reg lcd_rs;  // 0=command, 1=data
    
    // Message: "Hello from FPGA!" on line 1, "Nexys 4 DDR" on line 2
    reg [7:0] message [0:31];
    initial begin
        message[0]="H"; message[1]="e"; message[2]="l"; message[3]="l";
        message[4]="o"; message[5]=" "; message[6]="f"; message[7]="r";
        message[8]="o"; message[9]="m"; message[10]=" "; message[11]="F";
        message[12]="P"; message[13]="G"; message[14]="A"; message[15]="!";
        message[16]="N"; message[17]="e"; message[18]="x"; message[19]="y";
        message[20]="s"; message[21]=" "; message[22]="4"; message[23]=" ";
        message[24]="D"; message[25]="D"; message[26]="R"; message[27]=" ";
        message[28]=" "; message[29]=" "; message[30]=" "; message[31]=" ";
    end
    
    // Init commands
    reg [7:0] init_cmd [0:6];
    initial begin
        init_cmd[0] = 8'h33; // Initialize
        init_cmd[1] = 8'h32; // 4-bit mode
        init_cmd[2] = 8'h28; // 2 line, 5x8
        init_cmd[3] = 8'h0C; // Display on, cursor off
        init_cmd[4] = 8'h06; // Entry mode
        init_cmd[5] = 8'h01; // Clear
        init_cmd[6] = 8'h80; // Line 1
    end
    
    // Debug LEDs
    assign led[1:0] = state;
    assign led[5:2] = lcd_step;
    assign led[6] = i2c_ena;
    assign led[7] = prev_busy;
    assign led[8] = i2c_busy;
    assign led[9] = i2c_ack_error;
    assign led[15:10] = cmd_idx[5:0];
    
    // Detect I2C transaction complete
    wire i2c_done = prev_busy & ~i2c_busy;
    
    // Main FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            delay_cnt <= 0;
            cmd_idx <= 0;
            char_idx <= 0;
            i2c_ena <= 0;
            lcd_step <= 0;
            prev_busy <= 0;
            lcd_rs <= 0;
        end else begin
            prev_busy <= i2c_busy;
            
            case (state)
                IDLE: begin
                    if (delay_cnt < 100_000_000) // 1s startup delay
                        delay_cnt <= delay_cnt + 1;
                    else begin
                        state <= INIT;
                        delay_cnt <= 0;
                        lcd_step <= 0;
                        cmd_idx <= 0;
                    end
                end
                
                INIT: begin
                    case (lcd_step)
                        0: begin // Load command
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
                        
                        1: begin // Send high nibble, EN high
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b1, 1'b0, lcd_rs}; // BL=1, EN=1
                                i2c_ena <= 1;
                                lcd_step <= 2;
                            end
                        end
                        
                        2: begin // Wait for I2C complete
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 3;
                        end
                        
                        3: begin // Send high nibble, EN low
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[7:4], 1'b1, 1'b0, 1'b0, lcd_rs}; // BL=1, EN=0
                                i2c_ena <= 1;
                                lcd_step <= 4;
                            end
                        end
                        
                        4: begin // Wait for I2C complete
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 5;
                        end
                        
                        5: begin // Send low nibble, EN high
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b1, 1'b0, lcd_rs}; // BL=1, EN=1
                                i2c_ena <= 1;
                                lcd_step <= 6;
                            end
                        end
                        
                        6: begin // Wait for I2C complete
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 7;
                        end
                        
                        7: begin // Send low nibble, EN low
                            if (!i2c_busy && !i2c_ena) begin
                                i2c_data_wr <= {lcd_byte[3:0], 1'b1, 1'b0, 1'b0, lcd_rs}; // BL=1, EN=0
                                i2c_ena <= 1;
                                lcd_step <= 8;
                            end
                        end
                        
                        8: begin // Wait and delay
                            if (i2c_busy) i2c_ena <= 0;
                            if (i2c_done) lcd_step <= 9;
                        end
                        
                        9: begin // Delay between commands
                            if (delay_cnt < 500_000) // 5ms
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
                        0: begin // Load character or command
                            if (char_idx == 16) begin
                                lcd_byte <= 8'hC0; // Move to line 2
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
                        
                        1: begin // Send high nibble, EN high
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
                        
                        3: begin // Send high nibble, EN low
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
                        
                        5: begin // Send low nibble, EN high
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
                        
                        7: begin // Send low nibble, EN low
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
                    i2c_ena <= 0;
                    // Stay in DONE state
                end
            endcase
        end
    end
    
    // I2C master instance
    i2c_master #(
        .input_clk(100_000_000), 
        .bus_clk(100_000)
    ) i2c (
        .clk(clk),
        .reset_n(~rst),
        .ena(i2c_ena),
        .addr(I2C_ADDR),
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
    
    localparam READY = 0;
    localparam START = 1;
    localparam COMMAND = 2;
    localparam SLV_ACK1 = 3;
    localparam WR = 4;
    localparam SLV_ACK2 = 5;
    localparam STOP = 6;
    
    reg [2:0] state;
    reg [15:0] count;
    reg scl_clk;
    reg scl_ena;
    reg sda_int;
    reg sda_ena_n;
    reg [7:0] addr_rw;
    reg [7:0] data_tx;
    reg [2:0] bit_cnt;
    
    assign scl = (scl_ena == 1'b0) ? 1'b1 : scl_clk;
    assign sda = (sda_ena_n == 1'b0) ? sda_int : 1'bz;
    
    // Generate SCL clock
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
    
    // I2C state machine
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
