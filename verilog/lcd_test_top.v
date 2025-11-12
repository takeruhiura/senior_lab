module lcd_test_top(
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button (BTNC)
    inout wire sda,           // I2C data
    output wire scl,          // I2C clock
    output wire [15:0] led    // Debug LEDs
);

    // Try address 0x27 first, if doesn't work change to 0x3F
    parameter I2C_ADDR = 7'h27;  // Common addresses: 0x27 or 0x3F
    
    wire sda_out, sda_en;
    wire [7:0] state_debug;
    
    // Tri-state SDA
    assign sda = sda_en ? sda_out : 1'bz;
    
    // Debug LEDs show state
    assign led[7:0] = state_debug;
    assign led[15:8] = 8'h00;
    
    i2c_lcd_2004 #(
        .I2C_ADDR(I2C_ADDR)
    ) lcd (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda_out(sda_out),
        .sda_in(sda),
        .sda_en(sda_en),
        .state_debug(state_debug)
    );

endmodule

module i2c_lcd_2004 #(
    parameter I2C_ADDR = 7'h27
)(
    input wire clk,
    input wire rst,
    output reg scl,
    output reg sda_out,
    input wire sda_in,
    output reg sda_en,
    output reg [7:0] state_debug
);

    // I2C LCD uses PCF8574 with this bit mapping:
    // Bit 7: D7, Bit 6: D6, Bit 5: D5, Bit 4: D4
    // Bit 3: Backlight, Bit 2: E (Enable), Bit 1: RW, Bit 0: RS
    localparam BL = 3, EN = 2, RW = 1, RS = 0;
    
    // States
    localparam INIT = 0, DELAY = 1, SEND_I2C = 2, 
               WRITE_TEXT = 3, DONE = 4, IDLE = 5;
    
    reg [7:0] state;
    reg [31:0] delay_cnt;
    reg [7:0] init_step;
    reg [7:0] char_index;
    
    // I2C signals
    reg i2c_start;
    reg [7:0] i2c_data;
    wire i2c_busy;
    wire i2c_done;
    
    // LCD initialization sequence
    reg [7:0] lcd_cmd;
    reg lcd_cmd_valid;
    
    // Text to display: "Hello World!" on line 1, "I2C LCD 2004!" on line 2
    reg [7:0] text_mem [0:31];
    initial begin
        // Line 1: "    Hello World!    "
        text_mem[0]  = " "; text_mem[1]  = " "; text_mem[2]  = " "; text_mem[3]  = " ";
        text_mem[4]  = "H"; text_mem[5]  = "e"; text_mem[6]  = "l"; text_mem[7]  = "l";
        text_mem[8]  = "o"; text_mem[9]  = " "; text_mem[10] = "W"; text_mem[11] = "o";
        text_mem[12] = "r"; text_mem[13] = "l"; text_mem[14] = "d"; text_mem[15] = "!";
        text_mem[16] = " "; text_mem[17] = " "; text_mem[18] = " "; text_mem[19] = " ";
        // Line 2: "  I2C LCD 2004!     "
        text_mem[20] = " "; text_mem[21] = " "; text_mem[22] = "I"; text_mem[23] = "2";
        text_mem[24] = "C"; text_mem[25] = " "; text_mem[26] = "L"; text_mem[27] = "C";
        text_mem[28] = "D"; text_mem[29] = " "; text_mem[30] = "2"; text_mem[31] = "0";
    end
    
    assign state_debug = state;
    
    // I2C master module instance
    i2c_master i2c (
        .clk(clk),
        .rst(rst),
        .start(i2c_start),
        .addr(I2C_ADDR),
        .data(i2c_data),
        .scl(scl),
        .sda_out(sda_out),
        .sda_in(sda_in),
        .sda_en(sda_en),
        .busy(i2c_busy),
        .done(i2c_done)
    );
    
    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            delay_cnt <= 0;
            init_step <= 0;
            char_index <= 0;
            i2c_start <= 0;
            lcd_cmd <= 0;
            lcd_cmd_valid <= 0;
        end else begin
            case (state)
                INIT: begin
                    // Wait 50ms for LCD power up
                    if (delay_cnt < 5000000) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        init_step <= 0;
                        state <= SEND_I2C;
                    end
                end
                
                SEND_I2C: begin
                    if (!i2c_busy && !lcd_cmd_valid) begin
                        // Generate LCD commands based on init_step
                        case (init_step)
                            // Initialization sequence for 4-bit mode
                            0: begin lcd_cmd <= 8'h33; lcd_cmd_valid <= 1; end  // Init
                            1: begin lcd_cmd <= 8'h32; lcd_cmd_valid <= 1; end  // 4-bit mode
                            2: begin lcd_cmd <= 8'h28; lcd_cmd_valid <= 1; end  // 2 lines, 5x8
                            3: begin lcd_cmd <= 8'h0C; lcd_cmd_valid <= 1; end  // Display ON
                            4: begin lcd_cmd <= 8'h06; lcd_cmd_valid <= 1; end  // Entry mode
                            5: begin lcd_cmd <= 8'h01; lcd_cmd_valid <= 1; end  // Clear
                            6: begin lcd_cmd <= 8'h80; lcd_cmd_valid <= 1; end  // Set cursor line 1
                            default: begin
                                init_step <= 0;
                                char_index <= 0;
                                state <= WRITE_TEXT;
                            end
                        endcase
                    end else if (lcd_cmd_valid && !i2c_busy) begin
                        // Send command to LCD via I2C
                        lcd_send_cmd(lcd_cmd);
                        lcd_cmd_valid <= 0;
                    end else if (i2c_done) begin
                        delay_cnt <= 0;
                        state <= DELAY;
                    end
                end
                
                DELAY: begin
                    if (delay_cnt < 50000) begin  // Small delay between commands
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        init_step <= init_step + 1;
                        state <= SEND_I2C;
                    end
                end
                
                WRITE_TEXT: begin
                    if (!i2c_busy) begin
                        if (char_index < 20) begin
                            // Write first line
                            lcd_send_data(text_mem[char_index]);
                            char_index <= char_index + 1;
                        end else if (char_index == 20) begin
                            // Move to second line
                            lcd_cmd <= 8'hC0;  // Line 2 address
                            lcd_cmd_valid <= 1;
                            char_index <= char_index + 1;
                            state <= SEND_I2C;
                        end else if (char_index < 32) begin
                            // Write second line
                            lcd_send_data(text_mem[char_index]);
                            char_index <= char_index + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    state <= IDLE;
                end
                
                IDLE: begin
                    // Stay idle
                end
            endcase
        end
    end
    
    // Task to send command to LCD
    task lcd_send_cmd;
        input [7:0] cmd;
        begin
            // Send high nibble with E pulse
            i2c_data <= {cmd[7:4], 1'b1, 1'b1, 1'b0, 1'b0};  // BL=1, E=1, RW=0, RS=0
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            // Wait and clear E
            @(posedge i2c_done);
            i2c_data <= {cmd[7:4], 1'b1, 1'b0, 1'b0, 1'b0};  // E=0
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            // Send low nibble
            @(posedge i2c_done);
            i2c_data <= {cmd[3:0], 1'b1, 1'b1, 1'b0, 1'b0};  // E=1
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            @(posedge i2c_done);
            i2c_data <= {cmd[3:0], 1'b1, 1'b0, 1'b0, 1'b0};  // E=0
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
        end
    endtask
    
    // Task to send data to LCD
    task lcd_send_data;
        input [7:8] data;
        begin
            // Send high nibble with RS=1 (data mode)
            i2c_data <= {data[7:4], 1'b1, 1'b1, 1'b0, 1'b1};  // BL=1, E=1, RW=0, RS=1
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            @(posedge i2c_done);
            i2c_data <= {data[7:4], 1'b1, 1'b0, 1'b0, 1'b1};  // E=0
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            @(posedge i2c_done);
            i2c_data <= {data[3:0], 1'b1, 1'b1, 1'b0, 1'b1};  // E=1
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
            
            @(posedge i2c_done);
            i2c_data <= {data[3:0], 1'b1, 1'b0, 1'b0, 1'b1};  // E=0
            i2c_start <= 1;
            @(posedge clk);
            i2c_start <= 0;
        end
    endtask

endmodule

// Simple I2C Master
module i2c_master(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [6:0] addr,
    input wire [7:0] data,
    output reg scl,
    output reg sda_out,
    input wire sda_in,
    output reg sda_en,
    output reg busy,
    output reg done
);

    localparam IDLE = 0, START_BIT = 1, ADDR_BITS = 2, 
               DATA_BITS = 3, ACK_BIT = 4, STOP_BIT = 5;
    
    reg [3:0] state;
    reg [3:0] bit_cnt;
    reg [15:0] clk_cnt;
    reg [7:0] data_buf;
    
    // I2C clock ~100kHz (100MHz / 1000 = 100kHz)
    localparam CLK_DIV = 500;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            scl <= 1;
            sda_out <= 1;
            sda_en <= 1;
            busy <= 0;
            done <= 0;
            bit_cnt <= 0;
            clk_cnt <= 0;
        end else begin
            done <= 0;
            
            case (state)
                IDLE: begin
                    scl <= 1;
                    sda_out <= 1;
                    if (start) begin
                        data_buf <= data;
                        busy <= 1;
                        state <= START_BIT;
                        clk_cnt <= 0;
                    end
                end
                
                START_BIT: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        sda_out <= 0;  // Start condition
                    end else begin
                        clk_cnt <= 0;
                        bit_cnt <= 0;
                        state <= ADDR_BITS;
                    end
                end
                
                ADDR_BITS: begin
                    if (clk_cnt < CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        if (bit_cnt < 7)
                            sda_out <= addr[6 - bit_cnt];
                        else
                            sda_out <= 0;  // Write bit
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state <= ACK_BIT;
                        end
                    end
                end
                
                ACK_BIT: begin
                    if (clk_cnt < CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;  // Release SDA for ACK
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        if (bit_cnt == 0) begin
                            bit_cnt <= 0;
                            state <= DATA_BITS;
                        end else begin
                            state <= STOP_BIT;
                        end
                    end
                end
                
                DATA_BITS: begin
                    if (clk_cnt < CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= data_buf[7 - bit_cnt];
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 1;
                            state <= ACK_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (clk_cnt < CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= 0;
                    end else if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_out <= 1;  // Stop condition
                        done <= 1;
                        busy <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
