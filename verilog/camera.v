// OV7670 Camera Interface Module
// Implements I2C/SCCB configuration and parallel data capture
// Based on camera.xdc pin assignments for Nexys-4 DDR

module ov7670_camera #(
    parameter CLK_FREQ = 100_000_000,  // Input clock frequency in Hz
    parameter XCLK_FREQ = 24_000_000  // Camera clock frequency (24MHz typical)
)(
    // System signals
    input wire clk,              // System clock (100MHz)
    input wire rst_n,            // Active low reset
    
    // Camera I2C/SCCB interface
    output reg ov7670_scl,       // I2C clock
    inout wire ov7670_sda,      // I2C data (bidirectional)
    
    // Camera parallel interface
    input wire ov7670_plk,       // Pixel clock from camera
    input wire ov7670_hs,        // Horizontal sync
    input wire ov7670_vs,        // Vertical sync
    input wire [7:0] ov7670_data, // Pixel data bus
    
    // Camera control signals
    output reg ov7670_xlk,       // External clock output to camera (24MHz)
    output reg ov7670_rei,       // Reset input (active low)
    output reg ov7670_pwdn,      // Power down (active high)
    
    // Output interface
    output reg [7:0] pixel_data, // Captured pixel data
    output reg pixel_valid,      // Valid pixel data strobe
    output reg frame_valid,      // Frame valid signal
    output reg [15:0] pixel_x,   // Current pixel X coordinate
    output reg [15:0] pixel_y,   // Current pixel Y coordinate
    
    // Configuration interface
    input wire config_start,     // Start configuration sequence
    output reg config_done,      // Configuration complete
    output reg config_error      // Configuration error
);

    // ============================================
    // Clock Generation for Camera (XCLK)
    // ============================================
    // Generate 24MHz clock from 100MHz system clock
    // Using clock divider: 100MHz / 24MHz ≈ 4.167
    // Using 4.17 ratio: toggle every 2.08 cycles ≈ 2 cycles
    
    localparam XCLK_DIV = (CLK_FREQ / (2 * XCLK_FREQ));
    reg [7:0] xclk_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xclk_counter <= 0;
            ov7670_xlk <= 0;
        end else begin
            if (xclk_counter >= XCLK_DIV - 1) begin
                xclk_counter <= 0;
                ov7670_xlk <= ~ov7670_xlk;
            end else begin
                xclk_counter <= xclk_counter + 1;
            end
        end
    end
    
    // ============================================
    // Camera Control Signals
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ov7670_rei <= 0;      // Reset camera
            ov7670_pwdn <= 0;     // Power up camera
        end else begin
            ov7670_rei <= 1;      // Release reset after initialization
            ov7670_pwdn <= 0;     // Keep camera powered
        end
    end
    
    // ============================================
    // I2C/SCCB Configuration Module
    // ============================================
    // OV7670 uses SCCB (Serial Camera Control Bus) which is similar to I2C
    // I2C address: 0x42 (write) / 0x43 (read) for OV7670
    
    localparam I2C_ADDR = 7'h42;
    
    // I2C state machine
    reg [3:0] i2c_state;
    reg [7:0] i2c_counter;
    reg [7:0] i2c_bit_counter;
    reg [7:0] i2c_data_reg;
    reg [7:0] i2c_addr_reg;
    reg [7:0] i2c_reg_addr;  // Register address to write
    reg [7:0] i2c_reg_data;   // Register data to write
    reg i2c_write_reg_addr;  // Flag: writing register address (first byte)
    reg i2c_sda_out;
    reg i2c_sda_en;
    reg i2c_start;
    reg i2c_busy;
    reg i2c_done;
    
    localparam I2C_IDLE = 0,
               I2C_START = 1,
               I2C_ADDR = 2,
               I2C_ADDR_ACK = 3,
               I2C_DATA = 4,
               I2C_DATA_ACK = 5,
               I2C_STOP = 6;
    
    // I2C clock generation (400kHz for fast mode)
    localparam I2C_CLK_DIV = CLK_FREQ / (4 * 400_000);  // Divide by 4 for 4-phase I2C
    reg [15:0] i2c_clk_counter;
    reg i2c_clk;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2c_clk_counter <= 0;
            i2c_clk <= 0;
        end else begin
            if (i2c_clk_counter >= I2C_CLK_DIV - 1) begin
                i2c_clk_counter <= 0;
                i2c_clk <= ~i2c_clk;
            end else begin
                i2c_clk_counter <= i2c_clk_counter + 1;
            end
        end
    end
    
    // I2C state machine
    always @(posedge i2c_clk or negedge rst_n) begin
        if (!rst_n) begin
            i2c_state <= I2C_IDLE;
            i2c_sda_out <= 1;
            i2c_sda_en <= 0;
            ov7670_scl <= 1;
            i2c_busy <= 0;
            i2c_bit_counter <= 0;
            i2c_write_reg_addr <= 1;
            i2c_done <= 0;
        end else begin
            i2c_done <= 0;
            case (i2c_state)
                I2C_IDLE: begin
                    if (i2c_start) begin
                        i2c_state <= I2C_START;
                        i2c_busy <= 1;
                        i2c_sda_en <= 1;
                        i2c_sda_out <= 0;  // Start condition
                        i2c_write_reg_addr <= 1;  // Start with register address
                    end else begin
                        i2c_sda_en <= 0;
                        i2c_sda_out <= 1;
                        ov7670_scl <= 1;
                    end
                end
                
                I2C_START: begin
                    ov7670_scl <= 0;
                    i2c_state <= I2C_ADDR;
                    i2c_bit_counter <= 7;
                end
                
                I2C_ADDR: begin
                    ov7670_scl <= 1;
                    i2c_sda_out <= i2c_addr_reg[i2c_bit_counter];
                    if (i2c_bit_counter == 0) begin
                        i2c_state <= I2C_ADDR_ACK;
                    end else begin
                        i2c_bit_counter <= i2c_bit_counter - 1;
                    end
                end
                
                I2C_ADDR_ACK: begin
                    ov7670_scl <= 0;
                    i2c_sda_en <= 0;  // Release SDA for ACK
                    i2c_state <= I2C_DATA;
                    i2c_bit_counter <= 7;
                end
                
                I2C_DATA: begin
                    ov7670_scl <= 1;
                    i2c_sda_en <= 1;
                    // Write register address first, then data
                    if (i2c_write_reg_addr) begin
                        i2c_sda_out <= i2c_reg_addr[i2c_bit_counter];
                    end else begin
                        i2c_sda_out <= i2c_reg_data[i2c_bit_counter];
                    end
                    if (i2c_bit_counter == 0) begin
                        i2c_state <= I2C_DATA_ACK;
                    end else begin
                        i2c_bit_counter <= i2c_bit_counter - 1;
                    end
                end
                
                I2C_DATA_ACK: begin
                    ov7670_scl <= 0;
                    i2c_sda_en <= 0;
                    if (i2c_write_reg_addr) begin
                        // After writing register address, write data
                        i2c_write_reg_addr <= 0;
                        i2c_state <= I2C_DATA;
                        i2c_bit_counter <= 7;
                    end else begin
                        // Both bytes written, send stop
                        i2c_state <= I2C_STOP;
                    end
                end
                
                I2C_STOP: begin
                    ov7670_scl <= 1;
                    i2c_sda_en <= 1;
                    i2c_sda_out <= 1;  // Stop condition
                    i2c_state <= I2C_IDLE;
                    i2c_busy <= 0;
                    i2c_done <= 1;
                end
            endcase
        end
    end
    
    // Tri-state SDA
    assign ov7670_sda = i2c_sda_en ? i2c_sda_out : 1'bz;
    
    // ============================================
    // Configuration Register Sequence
    // ============================================
    // OV7670 initialization registers
    // Common configuration for QVGA (320x240) RGB565
    
    localparam NUM_REGS = 20;
    reg [7:0] config_regs [0:NUM_REGS-1][0:1];  // [address, value]
    reg [7:0] config_index;
    reg [2:0] config_state;
    
    localparam CFG_IDLE = 0,
               CFG_WAIT = 1,
               CFG_WRITE = 2,
               CFG_DONE = 3;
    
    // Initialize configuration registers
    initial begin
        // Register initialization
        config_regs[0][0] = 8'h12; config_regs[0][1] = 8'h80; // Reset
        config_regs[1][0] = 8'h12; config_regs[1][1] = 8'h04; // COM7: QVGA RGB
        config_regs[2][0] = 8'h11; config_regs[2][1] = 8'h80; // CLKRC: External clock
        config_regs[3][0] = 8'h0C; config_regs[3][1] = 8'h00; // COM3: No scaling
        config_regs[4][0] = 8'h3E; config_regs[4][1] = 8'h00; // COM14: No PCLK divider
        config_regs[5][0] = 8'h40; config_regs[5][1] = 8'h10; // COM15: RGB565
        config_regs[6][0] = 8'h3A; config_regs[6][1] = 8'h04; // TSLB: RGB565
        config_regs[7][0] = 8'h14; config_regs[7][1] = 8'h38; // COM9: AGC ceiling
        config_regs[8][0] = 8'h4F; config_regs[8][1] = 8'hB3; // MTX1
        config_regs[9][0] = 8'h50; config_regs[9][1] = 8'hB3; // MTX2
        config_regs[10][0] = 8'h51; config_regs[10][1] = 8'h00; // MTX3
        config_regs[11][0] = 8'h52; config_regs[11][1] = 8'h3d; // MTX4
        config_regs[12][0] = 8'h53; config_regs[12][1] = 8'ha7; // MTX5
        config_regs[13][0] = 8'h54; config_regs[13][1] = 8'he4; // MTX6
        config_regs[14][0] = 8'h58; config_regs[14][1] = 8'h9e; // MTXS
        config_regs[15][0] = 8'h3D; config_regs[15][1] = 8'hC0; // COM13: UV saturation
        config_regs[16][0] = 8'h17; config_regs[16][1] = 8'h14; // HSTART
        config_regs[17][0] = 8'h18; config_regs[17][1] = 8'h02; // HSTOP
        config_regs[18][0] = 8'h32; config_regs[18][1] = 8'h80; // HREF
        config_regs[19][0] = 8'h19; config_regs[19][1] = 8'h03; // VSTART
    end
    
    reg [31:0] config_delay;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_state <= CFG_IDLE;
            config_index <= 0;
            config_done <= 0;
            config_error <= 0;
            i2c_start <= 0;
            config_delay <= 0;
        end else begin
            case (config_state)
                CFG_IDLE: begin
                    if (config_start) begin
                        config_state <= CFG_WAIT;
                        config_index <= 0;
                        config_done <= 0;
                        config_error <= 0;
                        config_delay <= CLK_FREQ / 10;  // 100ms delay
                    end
                end
                
                CFG_WAIT: begin
                    if (config_delay > 0) begin
                        config_delay <= config_delay - 1;
                    end else begin
                        config_state <= CFG_WRITE;
                    end
                end
                
                CFG_WRITE: begin
                    if (!i2c_busy && !i2c_start) begin
                        i2c_addr_reg <= {I2C_ADDR, 1'b0};  // Write address
                        i2c_reg_addr <= config_regs[config_index][0];  // Register address
                        i2c_reg_data <= config_regs[config_index][1];  // Register data
                        i2c_start <= 1;
                    end else if (i2c_done) begin
                        i2c_start <= 0;
                        if (config_index < NUM_REGS - 1) begin
                            config_index <= config_index + 1;
                            config_delay <= CLK_FREQ / 1000;  // 1ms delay between writes
                            config_state <= CFG_WAIT;
                        end else begin
                            config_state <= CFG_DONE;
                        end
                    end
                end
                
                CFG_DONE: begin
                    config_done <= 1;
                    config_state <= CFG_IDLE;
                end
            endcase
        end
    end
    
    // ============================================
    // Pixel Data Capture
    // ============================================
    // Capture pixel data on rising edge of pixel clock
    // OV7670 outputs data on falling edge of PCLK, so we capture on rising edge
    
    reg vs_prev, hs_prev;
    reg [15:0] x_counter, y_counter;
    reg frame_active;
    
    always @(posedge ov7670_plk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_data <= 0;
            pixel_valid <= 0;
            frame_valid <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            x_counter <= 0;
            y_counter <= 0;
            vs_prev <= 1;
            hs_prev <= 1;
            frame_active <= 0;
        end else begin
            // Detect VS falling edge (start of frame)
            if (!ov7670_vs && vs_prev) begin
                y_counter <= 0;
                x_counter <= 0;
                frame_active <= 1;
                frame_valid <= 1;
            end
            
            // Detect VS rising edge (end of frame)
            if (ov7670_vs && !vs_prev) begin
                frame_active <= 0;
                frame_valid <= 0;
            end
            
            // Detect HS falling edge (start of line)
            if (!ov7670_hs && hs_prev && frame_active) begin
                x_counter <= 0;
                y_counter <= y_counter + 1;
            end
            
            // Capture pixel data when HS is low (active line)
            if (frame_active && !ov7670_hs && !ov7670_vs) begin
                pixel_data <= ov7670_data;
                pixel_valid <= 1;
                pixel_x <= x_counter;
                pixel_y <= y_counter;
                x_counter <= x_counter + 1;
            end else begin
                pixel_valid <= 0;
            end
            
            vs_prev <= ov7670_vs;
            hs_prev <= ov7670_hs;
        end
    end

endmodule

