module oled_test_top(
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button (BTNC)
    inout wire sda,           // I2C data
    output wire scl,          // I2C clock
    output wire [15:0] led    // Debug LEDs
);

    // SSD1306 OLED I2C address (try 0x3C, if doesn't work try 0x3D)
    parameter I2C_ADDR = 7'h3C;  // Common: 0x3C or 0x3D
    
    wire sda_out, sda_en;
    wire [7:0] state_debug;
    wire scl_out;
    
    // Tri-state SDA
    assign sda = sda_en ? sda_out : 1'bz;
    assign scl = scl_out;
    
    // Debug LEDs show state
    assign led = {8'h00, state_debug};
    
    ssd1306_oled #(
        .I2C_ADDR(I2C_ADDR)
    ) oled (
        .clk(clk),
        .rst(rst),
        .scl(scl_out),
        .sda_out(sda_out),
        .sda_in(sda),
        .sda_en(sda_en),
        .state_debug(state_debug)
    );

endmodule

module ssd1306_oled #(
    parameter I2C_ADDR = 7'h3C
)(
    input wire clk,
    input wire rst,
    output wire scl,
    output wire sda_out,
    input wire sda_in,
    output wire sda_en,
    output wire [7:0] state_debug
);

    // States
    localparam IDLE = 0, INIT = 1, SEND_CMD = 2, SEND_DATA = 3, 
               CLEAR_SCREEN = 4, WRITE_TEXT = 5, DONE = 6, WAIT = 7;
    
    reg [7:0] state;
    reg [31:0] delay_cnt;
    reg [7:0] init_step;
    reg [15:0] pixel_index;
    
    // I2C control signals
    reg i2c_start;
    reg [7:0] i2c_data;
    reg is_command;  // 0 = command, 1 = data
    wire i2c_busy;
    wire i2c_done;
    
    assign state_debug = state;
    
    // SSD1306 initialization commands for 128x64 OLED
    reg [7:0] init_cmds [0:25];
    initial begin
        init_cmds[0]  = 8'hAE; // Display OFF
        init_cmds[1]  = 8'hD5; // Set display clock divide
        init_cmds[2]  = 8'h80; // Suggested ratio 0x80
        init_cmds[3]  = 8'hA8; // Set multiplex
        init_cmds[4]  = 8'h3F; // 1/64 duty (0x3F for 128x64)
        init_cmds[5]  = 8'hD3; // Set display offset
        init_cmds[6]  = 8'h00; // No offset
        init_cmds[7]  = 8'h40; // Set start line address (0x40)
        init_cmds[8]  = 8'h8D; // Charge pump setting
        init_cmds[9]  = 8'h14; // Enable charge pump (0x14)
        init_cmds[10] = 8'h20; // Set Memory Addressing Mode
        init_cmds[11] = 8'h00; // 0x00 = Horizontal Addressing Mode
        init_cmds[12] = 8'hA1; // Set Segment Re-map (0xA1)
        init_cmds[13] = 8'hC8; // Set COM Output Scan Direction (0xC8)
        init_cmds[14] = 8'hDA; // Set COM Pins hardware configuration
        init_cmds[15] = 8'h12; // 0x12 for 128x64
        init_cmds[16] = 8'h81; // Set contrast control
        init_cmds[17] = 8'hCF; // 0xCF (max brightness)
        init_cmds[18] = 8'hD9; // Set pre-charge period
        init_cmds[19] = 8'hF1; // 0xF1
        init_cmds[20] = 8'hDB; // Set VCOMH deselect level
        init_cmds[21] = 8'h40; // 0x40
        init_cmds[22] = 8'hA4; // Set Entire Display ON/OFF (0xA4 = normal)
        init_cmds[23] = 8'hA6; // Set Normal/Inverse Display (0xA6 = normal)
        init_cmds[24] = 8'h2E; // Deactivate scroll
        init_cmds[25] = 8'hAF; // Display ON (0xAF)
    end
    
    // Simple 5x8 font for "Hello World!"
    // Each character is 5 bytes wide
    reg [7:0] char_H [0:4]; reg [7:0] char_e [0:4]; reg [7:0] char_l [0:4];
    reg [7:0] char_o [0:4]; reg [7:0] char_W [0:4]; reg [7:0] char_r [0:4];
    reg [7:0] char_d [0:4]; reg [7:0] char_spc [0:4]; reg [7:0] char_exc [0:4];
    
    initial begin
        // H
        char_H[0] = 8'b01111111; char_H[1] = 8'b00001000; char_H[2] = 8'b00001000;
        char_H[3] = 8'b00001000; char_H[4] = 8'b01111111;
        // e
        char_e[0] = 8'b00111000; char_e[1] = 8'b01010100; char_e[2] = 8'b01010100;
        char_e[3] = 8'b01010100; char_e[4] = 8'b00011000;
        // l
        char_l[0] = 8'b00000000; char_l[1] = 8'b01000001; char_l[2] = 8'b01111111;
        char_l[3] = 8'b01000000; char_l[4] = 8'b00000000;
        // o
        char_o[0] = 8'b00111000; char_o[1] = 8'b01000100; char_o[2] = 8'b01000100;
        char_o[3] = 8'b01000100; char_o[4] = 8'b00111000;
        // space
        char_spc[0] = 8'b00000000; char_spc[1] = 8'b00000000; char_spc[2] = 8'b00000000;
        char_spc[3] = 8'b00000000; char_spc[4] = 8'b00000000;
        // W
        char_W[0] = 8'b01111111; char_W[1] = 8'b00100000; char_W[2] = 8'b00011000;
        char_W[3] = 8'b00100000; char_W[4] = 8'b01111111;
        // r
        char_r[0] = 8'b01111100; char_r[1] = 8'b00001000; char_r[2] = 8'b00000100;
        char_r[3] = 8'b00000100; char_r[4] = 8'b00001000;
        // d
        char_d[0] = 8'b00111000; char_d[1] = 8'b01000100; char_d[2] = 8'b01000100;
        char_d[3] = 8'b01000100; char_d[4] = 8'b01111111;
        // !
        char_exc[0] = 8'b00000000; char_exc[1] = 8'b00000000; char_exc[2] = 8'b01011111;
        char_exc[3] = 8'b00000000; char_exc[4] = 8'b00000000;
    end
    
    reg [7:0] text_string [0:11];
    reg [3:0] char_byte;
    
    initial begin
        text_string[0] = 0;  // H
        text_string[1] = 1;  // e
        text_string[2] = 2;  // l
        text_string[3] = 2;  // l
        text_string[4] = 3;  // o
        text_string[5] = 4;  // space
        text_string[6] = 5;  // W
        text_string[7] = 3;  // o
        text_string[8] = 6;  // r
        text_string[9] = 2;  // l
        text_string[10] = 7; // d
        text_string[11] = 8; // !
    end
    
    // I2C master instance
    i2c_master_oled i2c (
        .clk(clk),
        .rst(rst),
        .start(i2c_start),
        .addr(I2C_ADDR),
        .data(i2c_data),
        .is_cmd(~is_command),
        .scl(scl),
        .sda_out(sda_out),
        .sda_in(sda_in),
        .sda_en(sda_en),
        .busy(i2c_busy),
        .done(i2c_done)
    );
    
    // Get character bitmap
    function [7:0] get_char_byte;
        input [7:0] char_idx;
        input [2:0] byte_idx;
        begin
            case (char_idx)
                0: get_char_byte = char_H[byte_idx];
                1: get_char_byte = char_e[byte_idx];
                2: get_char_byte = char_l[byte_idx];
                3: get_char_byte = char_o[byte_idx];
                4: get_char_byte = char_spc[byte_idx];
                5: get_char_byte = char_W[byte_idx];
                6: get_char_byte = char_r[byte_idx];
                7: get_char_byte = char_d[byte_idx];
                8: get_char_byte = char_exc[byte_idx];
                default: get_char_byte = 8'h00;
            endcase
        end
    endfunction
    
    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            delay_cnt <= 0;
            init_step <= 0;
            pixel_index <= 0;
            i2c_start <= 0;
            is_command <= 0;
            char_byte <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (delay_cnt < 1000000) begin  // Wait 10ms
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    if (!i2c_busy && init_step < 26) begin
                        i2c_data <= init_cmds[init_step];
                        is_command <= 0;  // Command mode
                        i2c_start <= 1;
                        state <= WAIT;
                    end else if (init_step >= 26) begin
                        init_step <= 0;
                        pixel_index <= 0;
                        state <= CLEAR_SCREEN;
                    end
                end
                
                CLEAR_SCREEN: begin
                    if (!i2c_busy && pixel_index < 1024) begin  // 128x64/8 = 1024 bytes
                        i2c_data <= 8'hFF;  // Turn ON all pixels (was 8'h00)
                        is_command <= 1;  // Data mode
                        i2c_start <= 1;
                        pixel_index <= pixel_index + 1;
                        state <= WAIT;
                    end else if (pixel_index >= 1024) begin
                        // Skip text, just fill screen
                        state <= DONE;
                    end
                end
                
                WRITE_TEXT: begin
                    if (!i2c_busy) begin
                        if (pixel_index == 0 && char_byte == 0) begin
                            // Set page (row) to 3
                            i2c_data <= 8'hB3;  // Page 3
                            is_command <= 0;
                            i2c_start <= 1;
                            char_byte <= 1;
                            state <= WAIT;
                        end else if (pixel_index == 0 && char_byte == 1) begin
                            // Set column to 20
                            i2c_data <= 8'h00 | (20 & 8'h0F);  // Lower nibble
                            is_command <= 0;
                            i2c_start <= 1;
                            char_byte <= 2;
                            state <= WAIT;
                        end else if (pixel_index == 0 && char_byte == 2) begin
                            i2c_data <= 8'h10 | ((20 >> 4) & 8'h0F);  // Upper nibble
                            is_command <= 0;
                            i2c_start <= 1;
                            char_byte <= 0;
                            pixel_index <= 1;
                            state <= WAIT;
                        end else if (pixel_index > 0 && pixel_index <= 12) begin
                            // Write characters
                            if (char_byte < 5) begin
                                i2c_data <= get_char_byte(text_string[pixel_index-1], char_byte);
                                is_command <= 1;  // Data mode
                                i2c_start <= 1;
                                char_byte <= char_byte + 1;
                                state <= WAIT;
                            end else begin
                                // Add space between characters
                                i2c_data <= 8'h00;
                                is_command <= 1;
                                i2c_start <= 1;
                                char_byte <= 0;
                                pixel_index <= pixel_index + 1;
                                state <= WAIT;
                            end
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                WAIT: begin
                    i2c_start <= 0;
                    if (i2c_done) begin
                        if (state == WAIT && init_step < 26 && pixel_index == 0) begin
                            init_step <= init_step + 1;
                            state <= INIT;
                        end else if (state == WAIT && pixel_index < 1024 && init_step >= 26) begin
                            state <= CLEAR_SCREEN;
                        end else if (state == WAIT && pixel_index > 0) begin
                            state <= WRITE_TEXT;
                        end else begin
                            state <= INIT;
                        end
                    end
                end
                
                DONE: begin
                    state <= DONE;  // Stay done
                end
            endcase
        end
    end

endmodule

// I2C Master for OLED
module i2c_master_oled(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [6:0] addr,
    input wire [7:0] data,
    input wire is_cmd,  // 0 = command, 1 = data
    output reg scl,
    output reg sda_out,
    input wire sda_in,
    output reg sda_en,
    output reg busy,
    output reg done
);

    localparam IDLE = 0, START_BIT = 1, ADDR_BITS = 2, ACK1 = 3,
               CTRL_BYTE = 4, ACK2 = 5, DATA_BITS = 6, ACK3 = 7, STOP_BIT = 8;
    
    reg [3:0] state;
    reg [3:0] bit_cnt;
    reg [15:0] clk_cnt;
    reg [7:0] data_buf;
    reg [7:0] ctrl_byte;
    
    // I2C clock ~100kHz (was 500, trying slower for reliability)
    localparam CLK_DIV = 1000;
    
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
                        ctrl_byte <= is_cmd ? 8'h40 : 8'h00;  // Co=0, D/C=1 for data, 0 for command
                        busy <= 1;
                        state <= START_BIT;
                        clk_cnt <= 0;
                    end
                end
                
                START_BIT: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        sda_out <= 0;  // Start condition
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        bit_cnt <= 0;
                        scl <= 0;
                        state <= ADDR_BITS;
                    end
                end
                
                ADDR_BITS: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        if (bit_cnt < 7)
                            sda_out <= addr[6 - bit_cnt];
                        else
                            sda_out <= 0;  // Write bit
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state <= ACK1;
                        end
                    end
                end
                
                ACK1: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;  // Release for ACK
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= CTRL_BYTE;
                    end
                end
                
                CTRL_BYTE: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= ctrl_byte[7 - bit_cnt];
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state <= ACK2;
                        end
                    end
                end
                
                ACK2: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= data_buf[7 - bit_cnt];
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state <= ACK3;
                        end
                    end
                end
                
                ACK3: begin
                    if (clk_cnt < CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < CLK_DIV) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= STOP_BIT;
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
                        sda_out <= 0;
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        sda_out <= 1;  // Stop condition
                    end else begin
                        clk_cnt <= 0;
                        done <= 1;
                        busy <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
