module lcd_test_top(
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button (BTNC)
    inout wire sda,           // I2C data
    output wire scl,          // I2C clock
    output wire [15:0] led    // Debug LEDs
);

    // Try address 0x27 first, if doesn't work change to 0x3F
    // To change: modify the parameter below and re-synthesize
    parameter I2C_ADDR = 7'h3f;  // Common addresses: 0x27 or 0x3F
    // If LCD doesn't work, try: parameter I2C_ADDR = 7'h3F;
    
    wire sda_out, sda_en;
    wire [7:0] state_debug;
    
    // Tri-state SDA
    assign sda = sda_en ? sda_out : 1'bz;
    
    // Debug LEDs show state
    assign led = {8'h00, state_debug};
    
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
    output wire scl,
    output wire sda_out,
    input wire sda_in,
    output wire sda_en,
    output wire [7:0] state_debug
);

    // I2C LCD uses PCF8574 with this bit mapping:
    // Bit 7: D7, Bit 6: D6, Bit 5: D5, Bit 4: D4
    // Bit 3: Backlight, Bit 2: E (Enable), Bit 1: RW, Bit 0: RS
    localparam BL = 3, EN = 2, RW = 1, RS = 0;
    
    // States
    localparam INIT = 0, SEND_HIGH_NIBBLE = 1, CLEAR_E1 = 2, 
               SEND_LOW_NIBBLE = 3, CLEAR_E2 = 4, DELAY_STATE = 5,
               SEND_DATA_HIGH = 6, CLEAR_DE1 = 7, SEND_DATA_LOW = 8, 
               CLEAR_DE2 = 9, DONE = 10, IDLE = 11;
    
    reg [7:0] state;
    reg [31:0] delay_cnt;
    reg [31:0] timeout_cnt;  // Timeout counter for I2C operations
    reg [7:0] init_step;
    reg [7:0] char_index;
    
    // I2C signals
    reg i2c_start;
    reg [7:0] i2c_data;
    wire i2c_busy;
    wire i2c_done;
    
    // Internal I2C signals (driven by i2c_master)
    wire scl_internal;
    wire sda_out_internal;
    wire sda_en_internal;
    
    // LCD command/data registers
    reg [7:0] current_cmd;
    reg [7:0] current_data;
    reg is_data_mode;  // 0 = command, 1 = data
    
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
        .scl(scl_internal),
        .sda_out(sda_out_internal),
        .sda_in(sda_in),
        .sda_en(sda_en_internal),
        .busy(i2c_busy),
        .done(i2c_done)
    );
    
    // Connect internal signals to output ports
    assign scl = scl_internal;
    assign sda_out = sda_out_internal;
    assign sda_en = sda_en_internal;
    
    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            delay_cnt <= 0;
            timeout_cnt <= 0;
            init_step <= 0;
            char_index <= 0;
            i2c_start <= 0;
            current_cmd <= 0;
            current_data <= 0;
            is_data_mode <= 0;
        end else begin
            i2c_start <= 0;  // Default: don't start I2C
            
            // Timeout mechanism: if I2C takes too long, assume it failed and continue
            if (i2c_busy) begin
                if (timeout_cnt < 1000000) begin  // 10ms timeout
                    timeout_cnt <= timeout_cnt + 1;
                end
            end else begin
                timeout_cnt <= 0;
            end
            
            case (state)
                INIT: begin
                    // Wait 50ms for LCD power up (100MHz * 0.05s = 5,000,000)
                    if (delay_cnt < 5000000) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        init_step <= 0;
                        is_data_mode <= 0;
                        state <= SEND_HIGH_NIBBLE;
                    end
                end
                
                SEND_HIGH_NIBBLE: begin
                    if (!i2c_busy) begin
                        case (init_step)
                            0: current_cmd <= 8'h33;  // Init
                            1: current_cmd <= 8'h32;  // 4-bit mode
                            2: current_cmd <= 8'h28;  // 2 lines, 5x8
                            3: current_cmd <= 8'h0C;  // Display ON
                            4: current_cmd <= 8'h06;  // Entry mode
                            5: current_cmd <= 8'h01;  // Clear
                            6: current_cmd <= 8'h80;  // Set cursor line 1
                            default: begin
                                // Init complete, start writing text
                                char_index <= 0;
                                is_data_mode <= 1;
                                current_data <= text_mem[0];
                                state <= SEND_DATA_HIGH;
                            end
                        endcase
                        
                        if (init_step <= 6) begin
                            // Send high nibble with E=1, RS=0 (command mode)
                            i2c_data <= {current_cmd[7:4], 1'b1, 1'b1, 1'b0, 1'b0};  // BL=1, E=1, RW=0, RS=0
                            i2c_start <= 1;
                            state <= CLEAR_E1;
                        end
                    end
                end
                
                CLEAR_E1: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        // Clear E after high nibble (or timeout)
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        // Clear E after high nibble
                        i2c_data <= {current_cmd[7:4], 1'b1, 1'b0, 1'b0, 1'b0};  // E=0
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        state <= SEND_LOW_NIBBLE;
                    end
                end
                
                SEND_LOW_NIBBLE: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        // Send low nibble with E=1
                        i2c_data <= {current_cmd[3:0], 1'b1, 1'b1, 1'b0, 1'b0};  // E=1
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        state <= CLEAR_E2;
                    end
                end
                
                CLEAR_E2: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        // Clear E after low nibble (or timeout)
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        i2c_data <= {current_cmd[3:0], 1'b1, 1'b0, 1'b0, 1'b0};  // E=0
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        state <= DELAY_STATE;
                    end
                end
                
                DELAY_STATE: begin
                    // Always increment delay counter (delay happens after I2C transaction)
                    if (init_step == 5) begin
                        // Clear command needs longer delay (2ms = 200,000 cycles)
                        if (delay_cnt < 200000) begin
                            delay_cnt <= delay_cnt + 1;
                        end else begin
                            delay_cnt <= 0;
                            init_step <= init_step + 1;
                            state <= SEND_HIGH_NIBBLE;
                        end
                    end else if (init_step == 7) begin
                        // Cursor command delay (500us)
                        if (delay_cnt < 50000) begin
                            delay_cnt <= delay_cnt + 1;
                        end else begin
                            delay_cnt <= 0;
                            init_step <= 20;  // Mark as in data mode
                            is_data_mode <= 1;
                            state <= SEND_DATA_HIGH;
                        end
                    end else if (init_step >= 20) begin
                        // Data delay (100us)
                        if (delay_cnt < 10000) begin
                            delay_cnt <= delay_cnt + 1;
                        end else begin
                            delay_cnt <= 0;
                            state <= SEND_DATA_HIGH;
                        end
                    end else begin
                        // Delay between init commands (500us = 50,000 cycles)
                        if (delay_cnt < 50000) begin
                            delay_cnt <= delay_cnt + 1;
                        end else begin
                            delay_cnt <= 0;
                            if (init_step < 6) begin
                                init_step <= init_step + 1;
                                state <= SEND_HIGH_NIBBLE;
                            end else begin
                                // Init complete, start writing text
                                char_index <= 0;
                                is_data_mode <= 1;
                                current_data <= text_mem[0];
                                state <= SEND_DATA_HIGH;
                            end
                        end
                    end
                end
                
                SEND_DATA_HIGH: begin
                    if (!i2c_busy) begin
                        if (char_index < 20) begin
                            // Write first line
                            current_data <= text_mem[char_index];
                            // Send high nibble with RS=1 (data mode)
                            i2c_data <= {text_mem[char_index][7:4], 1'b1, 1'b1, 1'b0, 1'b1};  // BL=1, E=1, RW=0, RS=1
                            i2c_start <= 1;
                            state <= CLEAR_DE1;
                        end else if (char_index == 20) begin
                            // Move to second line
                            is_data_mode <= 0;
                            current_cmd <= 8'hC0;  // Line 2 address
                            init_step <= 7;  // Special marker for cursor command
                            state <= SEND_HIGH_NIBBLE;
                        end else if (char_index < 32) begin
                            // Write second line
                            current_data <= text_mem[char_index];
                            // Send high nibble with RS=1
                            i2c_data <= {text_mem[char_index][7:4], 1'b1, 1'b1, 1'b0, 1'b1};  // BL=1, E=1, RW=0, RS=1
                            i2c_start <= 1;
                            state <= CLEAR_DE1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                CLEAR_DE1: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        // Clear E after high nibble of data
                        i2c_data <= {current_data[7:4], 1'b1, 1'b0, 1'b0, 1'b1};  // E=0
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        state <= SEND_DATA_LOW;
                    end
                end
                
                SEND_DATA_LOW: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        // Send low nibble with E=1
                        i2c_data <= {current_data[3:0], 1'b1, 1'b1, 1'b0, 1'b1};  // E=1
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        state <= CLEAR_DE2;
                    end
                end
                
                CLEAR_DE2: begin
                    if (i2c_done || (timeout_cnt >= 1000000)) begin
                        if (timeout_cnt >= 1000000) begin
                            timeout_cnt <= 0;
                        end
                        // Clear E after low nibble, data complete
                        i2c_data <= {current_data[3:0], 1'b1, 1'b0, 1'b0, 1'b1};  // E=0
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                        delay_cnt <= 0;
                        char_index <= char_index + 1;
                        is_data_mode <= 1;
                        state <= DELAY_STATE;
                    end
                end
                
                DONE: begin
                    state <= IDLE;
                end
                
                IDLE: begin
                    // Periodically send backlight-on command to keep backlight on
                    if (delay_cnt < 10000000) begin  // Every 100ms
                        delay_cnt <= delay_cnt + 1;
                    end else if (!i2c_busy) begin
                        delay_cnt <= 0;
                        // Send backlight-on only (no LCD command, just backlight)
                        // Bit 3 = Backlight, all other bits = 0
                        i2c_data <= 8'h08;  // Backlight on, E=0, RW=0, RS=0, D7-D4=0
                        i2c_start <= 1;
                        timeout_cnt <= 0;
                    end
                end
            endcase
            
        end
    end

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
    reg [6:0] addr_buf;
    reg ack_after_addr;
    
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
            ack_after_addr <= 0;
        end else begin
            done <= 0;
            
            case (state)
                IDLE: begin
                    scl <= 1;
                    sda_out <= 1;
                    sda_en <= 1;
                    if (start) begin
                        data_buf <= data;
                        addr_buf <= addr;
                        busy <= 1;
                        state <= START_BIT;
                        clk_cnt <= 0;
                        ack_after_addr <= 0;
                    end
                end
                
                START_BIT: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        sda_out <= 0;  // Start condition: SDA goes low while SCL is high
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
                            sda_out <= addr_buf[6 - bit_cnt];
                        else
                            sda_out <= 0;  // Write bit (0 = write)
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            ack_after_addr <= 1;
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
                        sda_out <= 1;
                        if (ack_after_addr) begin
                            // ACK after address, send data
                            ack_after_addr <= 0;
                            bit_cnt <= 0;
                            state <= DATA_BITS;
                        end else begin
                            // ACK after data, send stop
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
                            bit_cnt <= 0;
                            ack_after_addr <= 0;
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
                        sda_out <= 1;  // Stop condition: SDA goes high while SCL is high
                        done <= 1;
                        busy <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
