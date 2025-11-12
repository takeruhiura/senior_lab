module lcd_test_top(
    input wire clk,           // 100MHz clock on Nexys 4 DDR
    input wire rst,           // Reset button
    inout wire sda,           // I2C data line
    output wire scl           // I2C clock line
);

    // I2C LCD typically at address 0x27 or 0x3F
    parameter LCD_ADDR = 7'h27;
    
    wire i2c_sda_out, i2c_sda_en;
    wire done;
    
    // Tri-state buffer for SDA
    assign sda = i2c_sda_en ? i2c_sda_out : 1'bz;
    
    lcd_controller #(
        .LCD_ADDR(LCD_ADDR)
    ) lcd_ctrl (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda_out(i2c_sda_out),
        .sda_in(sda),
        .sda_en(i2c_sda_en),
        .done(done)
    );

endmodule

module lcd_controller #(
    parameter LCD_ADDR = 7'h27
)(
    input wire clk,
    input wire rst,
    output reg scl,
    output reg sda_out,
    input wire sda_in,
    output reg sda_en,
    output reg done
);

    // State machine states
    localparam IDLE = 0, START = 1, SEND_ADDR = 2, SEND_DATA = 3, 
               STOP = 4, WAIT = 5, INIT = 6, WRITE_CMD = 7;
    
    reg [3:0] state;
    reg [7:0] data_byte;
    reg [3:0] bit_count;
    reg [31:0] delay_counter;
    reg [7:0] init_step;
    
    // I2C timing (for 100kHz I2C with 100MHz clock)
    localparam CLK_DIV = 500;  // 100MHz / (2 * 100kHz) = 500
    reg [15:0] clk_counter;
    reg i2c_clk_en;
    
    // Initialization commands for HD44780-based LCD
    reg [7:0] init_commands [0:7];
    initial begin
        init_commands[0] = 8'h30;  // Function set
        init_commands[1] = 8'h30;  // Function set
        init_commands[2] = 8'h30;  // Function set
        init_commands[3] = 8'h20;  // 4-bit mode
        init_commands[4] = 8'h28;  // 4-bit, 2 lines, 5x8 font
        init_commands[5] = 8'h0C;  // Display on, cursor off
        init_commands[6] = 8'h06;  // Entry mode
        init_commands[7] = 8'h01;  // Clear display
    end
    
    // Message: "Hello World!"
    reg [7:0] message [0:11];
    initial begin
        message[0] = "H";
        message[1] = "e";
        message[2] = "l";
        message[3] = "l";
        message[4] = "o";
        message[5] = " ";
        message[6] = "W";
        message[7] = "o";
        message[8] = "r";
        message[9] = "l";
        message[10] = "d";
        message[11] = "!";
    end
    
    reg [7:0] msg_index;
    reg [1:0] write_state;
    reg cmd_mode;  // 0 = data, 1 = command
    
    // Clock divider for I2C
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_counter <= 0;
            i2c_clk_en <= 0;
        end else begin
            if (clk_counter >= CLK_DIV - 1) begin
                clk_counter <= 0;
                i2c_clk_en <= 1;
            end else begin
                clk_counter <= clk_counter + 1;
                i2c_clk_en <= 0;
            end
        end
    end
    
    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            scl <= 1;
            sda_out <= 1;
            sda_en <= 1;
            done <= 0;
            delay_counter <= 0;
            init_step <= 0;
            msg_index <= 0;
            write_state <= 0;
            cmd_mode <= 1;
        end else if (i2c_clk_en) begin
            case (state)
                INIT: begin
                    // Wait for LCD power-up (50ms)
                    if (delay_counter < 5000000) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        state <= WRITE_CMD;
                        init_step <= 0;
                    end
                end
                
                WRITE_CMD: begin
                    if (init_step < 8) begin
                        // Send initialization commands
                        data_byte <= init_commands[init_step];
                        cmd_mode <= 1;
                        state <= START;
                    end else if (msg_index < 12) begin
                        // Send message characters
                        data_byte <= message[msg_index];
                        cmd_mode <= 0;
                        state <= START;
                    end else begin
                        state <= IDLE;
                        done <= 1;
                    end
                end
                
                START: begin
                    // I2C start condition
                    sda_en <= 1;
                    sda_out <= 0;
                    bit_count <= 0;
                    state <= SEND_ADDR;
                end
                
                SEND_ADDR: begin
                    if (bit_count < 7) begin
                        scl <= ~scl;
                        if (scl) begin
                            sda_out <= LCD_ADDR[6 - bit_count];
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        scl <= ~scl;
                        if (scl) begin
                            sda_out <= 0;  // Write bit
                            state <= SEND_DATA;
                            bit_count <= 0;
                        end
                    end
                end
                
                SEND_DATA: begin
                    // Simplified: send data byte
                    // In real implementation, need to handle ACK/NACK
                    if (bit_count < 8) begin
                        scl <= ~scl;
                        if (scl) begin
                            sda_out <= data_byte[7 - bit_count];
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        state <= STOP;
                    end
                end
                
                STOP: begin
                    // I2C stop condition
                    scl <= 1;
                    sda_out <= 1;
                    state <= WAIT;
                    delay_counter <= 0;
                end
                
                WAIT: begin
                    // Wait between commands
                    if (delay_counter < 50000) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        if (init_step < 8) begin
                            init_step <= init_step + 1;
                        end else begin
                            msg_index <= msg_index + 1;
                        end
                        state <= WRITE_CMD;
                    end
                end
                
                IDLE: begin
                    scl <= 1;
                    sda_out <= 1;
                end
            endcase
        end
    end

endmodule
