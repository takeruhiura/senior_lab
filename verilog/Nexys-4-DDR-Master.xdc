module oled_test_top(
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button (BTNC)
    inout wire sda,           // I2C data
    output wire scl,          // I2C clock
    output wire [15:0] led    // Debug LEDs
);

    // SSD1306 OLED I2C address (try 0x3C, if doesn't work try 0x3D)
    parameter I2C_ADDR = 7'h3C;
    
    wire sda_out, sda_en;
    wire [7:0] state_debug;
    wire scl_out;
    
    // Tri-state SDA
    assign sda = sda_en ? sda_out : 1'bz;
    assign scl = scl_out;
    
    // Debug LEDs show more info
    wire i2c_busy_w, i2c_done_w;
    wire [3:0] i2c_state_debug;
    assign led = {i2c_state_debug, i2c_busy_w, i2c_done_w, sda, scl, state_debug};
    
    ssd1306_oled #(
        .I2C_ADDR(I2C_ADDR)
    ) oled (
        .clk(clk),
        .rst(rst),
        .scl(scl_out),
        .sda_out(sda_out),
        .sda_in(sda),
        .sda_en(sda_en),
        .state_debug(state_debug),
        .i2c_state_debug(i2c_state_debug)
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
    output wire [7:0] state_debug,
    output wire i2c_busy_w,
    output wire i2c_done_w,
    output wire [3:0] i2c_state_debug
);

    // States - simplified
    localparam IDLE = 0, INIT = 1, WAIT = 2, DONE = 3;
    
    reg [7:0] state;
    reg [31:0] delay_cnt;
    reg [2:0] init_step;  // Only need 3 steps now
    
    // I2C control signals
    reg i2c_start;
    reg [7:0] i2c_data;
    reg is_command;  // 0 = command, 1 = data
    wire i2c_busy;
    wire i2c_done;
    
    assign state_debug = state;
    assign i2c_busy_w = i2c_busy;
    assign i2c_done_w = i2c_done;
    
    // Minimal SSD1306 initialization - just turn on the display
    // Only 3 essential commands:
    reg [7:0] init_cmds [0:2];
    initial begin
        init_cmds[0] = 8'h8D; // Charge pump setting
        init_cmds[1] = 8'h14; // Enable charge pump (required for display power)
        init_cmds[2] = 8'hAF; // Display ON
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
        .done(i2c_done),
        .state_debug(i2c_state_debug)
    );
    
    // Main state machine - simplified to just turn on display
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            delay_cnt <= 0;
            init_step <= 0;
            i2c_start <= 0;
            is_command <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (delay_cnt < 10000000) begin  // Wait 100ms for power stabilization
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    if (!i2c_busy && init_step < 3) begin
                        i2c_data <= init_cmds[init_step];
                        is_command <= 0;  // All are commands
                        i2c_start <= 1;
                        state <= WAIT;
                    end else if (i2c_busy) begin
                        // I2C has started, clear start signal
                        i2c_start <= 0;
                    end else if (init_step >= 3) begin
                        // All commands sent, we're done
                        state <= DONE;
                    end
                end
                
                WAIT: begin
                    // Clear start signal once I2C is busy
                    if (i2c_busy) begin
                        i2c_start <= 0;
                    end
                    // Add timeout to prevent infinite wait
                    if (delay_cnt > 50000000) begin  // 500ms timeout
                        delay_cnt <= 0;
                        i2c_start <= 0;
                        // Timeout - try to continue or give up
                        if (init_step < 3) begin
                            init_step <= init_step + 1;
                            state <= INIT;
                        end else begin
                            state <= DONE;  // Give up
                        end
                    end else if (i2c_done) begin
                        delay_cnt <= 0;
                        i2c_start <= 0;
                        // Move to next command or finish
                        if (init_step < 3) begin
                            init_step <= init_step + 1;
                            state <= INIT;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end
                
                DONE: begin
                    state <= DONE;  // Stay done - display should be on now
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
    output reg done,
    output wire [3:0] state_debug
);

    localparam IDLE = 0, START_BIT = 1, ADDR_BITS = 2, ACK1 = 3,
               CTRL_BYTE = 4, ACK2 = 5, DATA_BITS = 6, ACK3 = 7, STOP_BIT = 8;
    
    reg [3:0] state;
    assign state_debug = state;
    reg [3:0] bit_cnt;
    reg [15:0] clk_cnt;
    reg [7:0] data_buf;
    reg [7:0] ctrl_byte;
    
    // I2C clock ~100kHz (meets timing specs: tcycle min 2.5us = 400kHz max)
    // At 100MHz: 1000 cycles = 10us period = 100kHz
    localparam CLK_DIV = 1000;
    
    // Timing constants (at 100MHz, 1 cycle = 10ns)
    // tHSTART min = 0.6us = 60 cycles
    // tSD min = 100ns = 10 cycles  
    // tHD min = 300ns = 30 cycles (for SDAIN)
    // tSSTOP min = 0.6us = 60 cycles
    // tIDLE min = 1.3us = 130 cycles
    localparam T_HSTART = 100;  // 1us (well above 0.6us min)
    localparam T_SETUP = 50;     // 0.5us (well above 100ns min)
    localparam T_HOLD = 50;      // 0.5us (well above 300ns min)
    localparam T_SSTOP = 100;    // 1us (well above 0.6us min)
    localparam T_IDLE = 200;     // 2us (well above 1.3us min)
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            scl <= 1;
            sda_out <= 1;
            sda_en <= 1;
            busy <= 0;
            done <= 0;
            bit_cnt <= 0;
            clk_cnt <= T_IDLE;  // Start with idle time satisfied
        end else begin
            done <= 0;
            
            case (state)
                IDLE: begin
                    scl <= 1;
                    sda_out <= 1;
                    sda_en <= 1;
                    if (start && clk_cnt >= T_IDLE) begin
                        data_buf <= data;
                        ctrl_byte <= is_cmd ? 8'h00 : 8'h40;  // Co=0, D/C=0 for command (0x00), D/C=1 for data (0x40)
                        busy <= 1;
                        state <= START_BIT;
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                START_BIT: begin
                    if (clk_cnt < T_HSTART) begin
                        clk_cnt <= clk_cnt + 1;
                        sda_out <= 0;  // Start condition: SDA high-to-low while SCL high
                        scl <= 1;
                    end else begin
                        clk_cnt <= 0;
                        bit_cnt <= 0;
                        scl <= 0;
                        state <= ADDR_BITS;
                    end
                end
                
                ADDR_BITS: begin
                    if (clk_cnt < T_HOLD) begin
                        // Hold time: set data early, keep stable after SCL goes low
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        if (bit_cnt < 7)
                            sda_out <= addr[6 - bit_cnt];
                        else
                            sda_out <= 0;  // Write bit
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        // Setup time: data already stable before SCL goes high
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        if (bit_cnt < 7)
                            sda_out <= addr[6 - bit_cnt];
                        else
                            sda_out <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        // SCL high phase
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
                    if (clk_cnt < T_HOLD) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;  // Release SDA for ACK
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;  // Keep SDA released
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;  // Sample ACK (SDA should be low)
                        sda_en <= 0;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= CTRL_BYTE;
                    end
                end
                
                CTRL_BYTE: begin
                    if (clk_cnt < T_HOLD) begin
                        // Hold time: set data early
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= ctrl_byte[7 - bit_cnt];
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        // Setup time: data already stable
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= ctrl_byte[7 - bit_cnt];
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        // SCL high phase
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
                    if (clk_cnt < T_HOLD) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;  // Sample ACK
                        sda_en <= 0;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_cnt < T_HOLD) begin
                        // Hold time: set data early
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= data_buf[7 - bit_cnt];
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        // Setup time: data already stable
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= data_buf[7 - bit_cnt];
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        // SCL high phase
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
                    if (clk_cnt < T_HOLD) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_en <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP + CLK_DIV/2) begin
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;  // Sample ACK
                        sda_en <= 0;
                    end else begin
                        clk_cnt <= 0;
                        sda_en <= 1;
                        state <= STOP_BIT;
                    end
                end
                
                STOP_BIT: begin
                    if (clk_cnt < T_HOLD) begin
                        // Bring SCL low first
                        clk_cnt <= clk_cnt + 1;
                        scl <= 0;
                        sda_out <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP) begin
                        // Setup: bring SCL high while SDA is still low
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                        sda_out <= 0;
                    end else if (clk_cnt < T_HOLD + T_SETUP + T_SSTOP) begin
                        // Stop condition: SDA low-to-high while SCL high (tSSTOP)
                        clk_cnt <= clk_cnt + 1;
                        scl <= 1;
                        sda_out <= 1;
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
