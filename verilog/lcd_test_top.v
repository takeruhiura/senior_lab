module lcd_test_top(
    input wire clk,
    input wire rst,
    inout wire sda,
    output wire scl,
    output wire [15:0] led
);

    parameter I2C_ADDR = 7'h20;  // Your detected address
    
    wire sda_out, sda_en;
    wire [7:0] state_debug;
    
    assign sda = sda_en ? sda_out : 1'bz;
    assign led = {8'h00, state_debug};
    
    simple_lcd_test #(.I2C_ADDR(I2C_ADDR)) lcd (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda_out(sda_out),
        .sda_in(sda),
        .sda_en(sda_en),
        .state_debug(state_debug)
    );

endmodule

module simple_lcd_test #(
    parameter I2C_ADDR = 7'h20
)(
    input wire clk,
    input wire rst,
    output wire scl,
    output wire sda_out,
    input wire sda_in,
    output wire sda_en,
    output wire [7:0] state_debug
);

    localparam IDLE = 0;
    localparam WAIT_POWER = 1;
    localparam INIT_1 = 2;
    localparam INIT_2 = 3;
    localparam INIT_3 = 4;
    localparam FUNC_SET = 5;
    localparam DISPLAY_ON = 6;
    localparam CLEAR = 7;
    localparam WRITE_CHAR = 8;
    localparam DONE = 9;
    
    reg [3:0] state;
    reg [31:0] counter;
    reg [7:0] cmd_data;
    reg [3:0] nibble_state;
    reg i2c_go;
    
    wire i2c_busy;
    wire i2c_done;
    
    assign state_debug = state;
    
    // I2C master
    wire scl_int, sda_out_int, sda_en_int;
    assign scl = scl_int;
    assign sda_out = sda_out_int;
    assign sda_en = sda_en_int;
    
    i2c_master i2c (
        .clk(clk),
        .rst(rst),
        .start(i2c_go),
        .addr(I2C_ADDR),
        .data(cmd_data),
        .scl(scl_int),
        .sda_out(sda_out_int),
        .sda_in(sda_in),
        .sda_en(sda_en_int),
        .busy(i2c_busy),
        .done(i2c_done)
    );
    
    // Simple state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAIT_POWER;
            counter <= 0;
            nibble_state <= 0;
            i2c_go <= 0;
        end else begin
            i2c_go <= 0;
            
            case (state)
                WAIT_POWER: begin
                    if (counter < 1_000_000) // 10ms - much shorter delay
                        counter <= counter + 1;
                    else begin
                        counter <= 0;
                        state <= INIT_1;
                        nibble_state <= 0;
                    end
                end
                
                INIT_1: begin
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00110000;  // 0x30, BL=1, E=1
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: begin
                            if (i2c_done) nibble_state <= 2;
                        end
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00100000;  // E=0
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: begin
                            if (i2c_done) begin
                                if (counter < 5_000_000) // 50ms
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= INIT_2;
                                end
                            end
                        end
                    endcase
                end
                
                INIT_2: begin
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00110000;
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: begin
                            if (i2c_done) nibble_state <= 2;
                        end
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00100000;
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: begin
                            if (i2c_done) begin
                                if (counter < 1_000_000) // 10ms
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= INIT_3;
                                end
                            end
                        end
                    endcase
                end
                
                INIT_3: begin
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00100000;  // 4-bit mode
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: begin
                            if (i2c_done) nibble_state <= 2;
                        end
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00000000;
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: begin
                            if (i2c_done) begin
                                if (counter < 1_000_000)
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= FUNC_SET;
                                end
                            end
                        end
                    endcase
                end
                
                FUNC_SET: begin // Send 0x28 (2 lines, 5x8)
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00101000;  // High nibble: 0010, E=1
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: if (i2c_done) nibble_state <= 2;
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00001000;  // E=0
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: if (i2c_done) nibble_state <= 4;
                        4: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b10001000;  // Low nibble: 1000, E=1
                                i2c_go <= 1;
                                nibble_state <= 5;
                            end
                        end
                        5: if (i2c_done) nibble_state <= 6;
                        6: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b10000000;  // E=0
                                i2c_go <= 1;
                                nibble_state <= 7;
                            end
                        end
                        7: begin
                            if (i2c_done) begin
                                if (counter < 100_000)
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= DISPLAY_ON;
                                end
                            end
                        end
                    endcase
                end
                
                DISPLAY_ON: begin // Send 0x0C (display on, no cursor)
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00001000;  // 0000, E=1
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: if (i2c_done) nibble_state <= 2;
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00000000;  // E=0
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: if (i2c_done) nibble_state <= 4;
                        4: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b11001000;  // 1100, E=1
                                i2c_go <= 1;
                                nibble_state <= 5;
                            end
                        end
                        5: if (i2c_done) nibble_state <= 6;
                        6: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b11000000;  // E=0
                                i2c_go <= 1;
                                nibble_state <= 7;
                            end
                        end
                        7: begin
                            if (i2c_done) begin
                                if (counter < 100_000)
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= CLEAR;
                                end
                            end
                        end
                    endcase
                end
                
                CLEAR: begin // Send 0x01 (clear)
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00001000;  // 0000, E=1
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: if (i2c_done) nibble_state <= 2;
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00000000;
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: if (i2c_done) nibble_state <= 4;
                        4: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00011000;  // 0001, E=1
                                i2c_go <= 1;
                                nibble_state <= 5;
                            end
                        end
                        5: if (i2c_done) nibble_state <= 6;
                        6: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00010000;
                                i2c_go <= 1;
                                nibble_state <= 7;
                            end
                        end
                        7: begin
                            if (i2c_done) begin
                                if (counter < 2_000_000)  // 20ms for clear
                                    counter <= counter + 1;
                                else begin
                                    counter <= 0;
                                    nibble_state <= 0;
                                    state <= WRITE_CHAR;
                                end
                            end
                        end
                    endcase
                end
                
                WRITE_CHAR: begin // Write 'A' (0x41), RS=1
                    case (nibble_state)
                        0: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b01001001;  // 0100 (high nibble of 'A'), E=1, RS=1
                                i2c_go <= 1;
                                nibble_state <= 1;
                            end
                        end
                        1: if (i2c_done) nibble_state <= 2;
                        2: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b01000001;  // E=0, RS=1
                                i2c_go <= 1;
                                nibble_state <= 3;
                            end
                        end
                        3: if (i2c_done) nibble_state <= 4;
                        4: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00011001;  // 0001 (low nibble of 'A'), E=1, RS=1
                                i2c_go <= 1;
                                nibble_state <= 5;
                            end
                        end
                        5: if (i2c_done) nibble_state <= 6;
                        6: begin
                            if (!i2c_busy) begin
                                cmd_data <= 8'b00010001;  // E=0, RS=1
                                i2c_go <= 1;
                                nibble_state <= 7;
                            end
                        end
                        7: begin
                            if (i2c_done) begin
                                state <= DONE;
                            end
                        end
                    endcase
                end
                
                DONE: begin
                    // Stay here
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
    
    localparam CLK_DIV = 500;  // 100kHz I2C
    
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
                        sda_out <= 0;
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
                            sda_out <= 0;
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
                        sda_en <= 0;
                    end else if (clk_cnt < 3*CLK_DIV/4) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        sda_out <= 1;
                        if (ack_after_addr) begin
                            ack_after_addr <= 0;
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
                        sda_out <= 1;
                        done <= 1;
                        busy <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
