// Camera Test Top Module
// Tests OV7670 camera functionality with LED indicators
// Connect to camera.xdc constraints

module camera_test_top(
    // System signals
    input wire CLK100MHZ,        // 100MHz system clock
    input wire CPU_RESETN,       // Reset button (active low)
    
    // Camera I2C/SCCB interface
    output wire ov7670_scl,
    inout wire ov7670_sda,
    
    // Camera parallel interface
    input wire ov7670_plk,       // Pixel clock from camera
    input wire ov7670_hs,        // Horizontal sync
    input wire ov7670_vs,        // Vertical sync
    input wire [7:0] ov7670_data, // Pixel data bus
    
    // Camera control signals
    output wire ov7670_xlk,      // External clock output to camera
    output wire ov7670_rei,      // Reset input
    output wire ov7670_pwdn,     // Power down
    
    // Status LEDs
    output wire [15:0] LED,      // Status LEDs
    output wire LED16_R,         // Red LED - Config error
    output wire LED16_G,         // Green LED - Config done
    output wire LED16_B,         // Blue LED - Frame valid
    
    // Seven-segment display (optional - shows pixel count)
    output wire [7:0] AN,        // Anode select
    output wire [6:0] SEG,       // Segment outputs
    output wire DP               // Decimal point
);

    // ============================================
    // Internal Signals
    // ============================================
    wire rst_n = CPU_RESETN;
    
    // Camera module signals
    wire [7:0] pixel_data;
    wire pixel_valid;
    wire frame_valid;
    wire [15:0] pixel_x, pixel_y;
    wire config_done;
    wire config_error;
    
    // Configuration control
    reg config_start;
    reg [31:0] init_delay;
    reg config_triggered;
    
    // Pixel statistics
    reg [31:0] pixel_count;
    reg [31:0] frame_count;
    reg [31:0] last_frame_pixels;
    reg vs_prev;
    
    // LED indicators
    reg [23:0] led_blink_counter;
    reg pixel_clock_led;
    reg config_done_led;
    
    // ============================================
    // Camera Module Instantiation
    // ============================================
    ov7670_camera #(
        .CLK_FREQ(100_000_000),
        .XCLK_FREQ(24_000_000)
    ) camera_inst (
        .clk(CLK100MHZ),
        .rst_n(rst_n),
        .ov7670_scl(ov7670_scl),
        .ov7670_sda(ov7670_sda),
        .ov7670_plk(ov7670_plk),
        .ov7670_hs(ov7670_hs),
        .ov7670_vs(ov7670_vs),
        .ov7670_data(ov7670_data),
        .ov7670_xlk(ov7670_xlk),
        .ov7670_rei(ov7670_rei),
        .ov7670_pwdn(ov7670_pwdn),
        .pixel_data(pixel_data),
        .pixel_valid(pixel_valid),
        .frame_valid(frame_valid),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .config_start(config_start),
        .config_done(config_done),
        .config_error(config_error)
    );
    
    // ============================================
    // Configuration Trigger
    // ============================================
    // Auto-start configuration after reset
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            config_start <= 0;
            init_delay <= 0;
            config_triggered <= 0;
        end else begin
            if (!config_triggered && init_delay < 100_000_000) begin
                // Wait 1 second after reset before starting config
                init_delay <= init_delay + 1;
                config_start <= 0;
            end else if (!config_triggered) begin
                config_start <= 1;
                config_triggered <= 1;
            end else begin
                config_start <= 0;
            end
        end
    end
    
    // ============================================
    // Pixel Statistics
    // ============================================
    always @(posedge ov7670_plk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 0;
            frame_count <= 0;
            last_frame_pixels <= 0;
            vs_prev <= 1;
        end else begin
            vs_prev <= ov7670_vs;
            
            // Count pixels
            if (pixel_valid) begin
                pixel_count <= pixel_count + 1;
            end
            
            // Detect frame end (VS rising edge)
            if (ov7670_vs && !vs_prev) begin
                frame_count <= frame_count + 1;
                last_frame_pixels <= pixel_count;
                pixel_count <= 0;
            end
        end
    end
    
    // ============================================
    // LED Indicators
    // ============================================
    // Blink LED on pixel clock to verify camera is running
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            led_blink_counter <= 0;
            pixel_clock_led <= 0;
        end else begin
            led_blink_counter <= led_blink_counter + 1;
            // Toggle every ~0.5 seconds if pixel clock is active
            if (led_blink_counter == 50_000_000) begin
                led_blink_counter <= 0;
                if (ov7670_plk) begin
                    pixel_clock_led <= ~pixel_clock_led;
                end
            end
        end
    end
    
    // Config done LED (blinks when done)
    always @(posedge CLK100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            config_done_led <= 0;
        end else begin
            if (config_done) begin
                // Blink at 2Hz when config is done
                if (led_blink_counter[26]) begin
                    config_done_led <= 1;
                end else begin
                    config_done_led <= 0;
                end
            end else begin
                config_done_led <= 0;
            end
        end
    end
    
    // LED assignments
    assign LED[0] = config_done;           // Config done
    assign LED[1] = config_error;          // Config error
    assign LED[2] = frame_valid;           // Frame valid
    assign LED[3] = pixel_valid;           // Pixel valid (blinks fast)
    assign LED[4] = ov7670_plk;            // Pixel clock (raw)
    assign LED[5] = ov7670_hs;             // Horizontal sync
    assign LED[6] = ov7670_vs;             // Vertical sync
    assign LED[7] = pixel_clock_led;       // Pixel clock indicator (blinks)
    assign LED[8] = config_done_led;       // Config done indicator (blinks)
    assign LED[9] = (frame_count > 0);      // Frames received
    assign LED[10] = (pixel_count > 1000); // Pixels captured
    assign LED[11] = ov7670_xlk;           // External clock output
    assign LED[12] = config_start;         // Config start
    assign LED[13] = (last_frame_pixels > 0); // Last frame had pixels
    assign LED[14] = (last_frame_pixels > 10000); // Last frame had many pixels
    assign LED[15] = (last_frame_pixels > 50000); // Last frame had lots of pixels
    
    // RGB LED
    assign LED16_R = config_error;         // Red = error
    assign LED16_G = config_done;          // Green = config done
    assign LED16_B = frame_valid;         // Blue = frame valid
    
    // ============================================
    // Seven-Segment Display (Optional)
    // ============================================
    // Display pixel count or frame count on 7-seg display
    wire [3:0] digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7;
    
    // Extract digits from last_frame_pixels (16-bit value)
    assign digit0 = last_frame_pixels[3:0];
    assign digit1 = last_frame_pixels[7:4];
    assign digit2 = last_frame_pixels[11:8];
    assign digit3 = last_frame_pixels[15:12];
    
    // Extract digits from frame_count (32-bit value, show lower 16 bits)
    assign digit4 = frame_count[3:0];
    assign digit5 = frame_count[7:4];
    assign digit6 = frame_count[11:8];
    assign digit7 = frame_count[15:12];
    
    // Use existing display module if available, or create simple display
    // For now, just show frame count
    wire [3:0] d1 = digit7;
    wire [3:0] d2 = digit6;
    wire [3:0] d3 = digit5;
    wire [3:0] d4 = digit4;
    wire [3:0] d5 = digit3;
    wire [3:0] d6 = digit2;
    wire [3:0] d7 = digit1;
    wire [3:0] d8 = digit0;
    
    // Clock divider for 7-seg refresh
    reg [16:0] seg_clk_counter;
    reg clk_div;
    
    always @(posedge CLK100MHZ) begin
        if (!rst_n) begin
            seg_clk_counter <= 0;
            clk_div <= 0;
        end else begin
            if (seg_clk_counter == 99999) begin
                seg_clk_counter <= 0;
                clk_div <= 1;
            end else begin
                seg_clk_counter <= seg_clk_counter + 1;
                clk_div <= 0;
            end
        end
    end
    
    // 3-bit counter for digit selection
    reg [2:0] sel;
    always @(posedge CLK100MHZ) begin
        if (!rst_n) begin
            sel <= 0;
        end else if (clk_div) begin
            sel <= sel + 1;
        end
    end
    
    // Multiplexer for digit selection
    wire [3:0] selected_digit;
    assign selected_digit = (sel == 0) ? d1 :
                            (sel == 1) ? d2 :
                            (sel == 2) ? d3 :
                            (sel == 3) ? d4 :
                            (sel == 4) ? d5 :
                            (sel == 5) ? d6 :
                            (sel == 6) ? d7 :
                            d8;
    
    // Seven-segment decoder
    reg [6:0] seg_reg;
    always @(*) begin
        case (selected_digit)
            4'h0: seg_reg = 7'b1000000; // 0
            4'h1: seg_reg = 7'b1111001; // 1
            4'h2: seg_reg = 7'b0100100; // 2
            4'h3: seg_reg = 7'b0110000; // 3
            4'h4: seg_reg = 7'b0011001; // 4
            4'h5: seg_reg = 7'b0010010; // 5
            4'h6: seg_reg = 7'b0000010; // 6
            4'h7: seg_reg = 7'b1111000; // 7
            4'h8: seg_reg = 7'b0000000; // 8
            4'h9: seg_reg = 7'b0010000; // 9
            4'hA: seg_reg = 7'b0001000; // A
            4'hB: seg_reg = 7'b0000011; // b
            4'hC: seg_reg = 7'b1000110; // C
            4'hD: seg_reg = 7'b0100001; // d
            4'hE: seg_reg = 7'b0000110; // E
            4'hF: seg_reg = 7'b0001110; // F
            default: seg_reg = 7'b1111111; // blank
        endcase
    end
    assign SEG = seg_reg;
    
    // Anode decoder
    reg [7:0] an_reg;
    always @(*) begin
        case (sel)
            3'b000: an_reg = 8'b11111110;
            3'b001: an_reg = 8'b11111101;
            3'b010: an_reg = 8'b11111011;
            3'b011: an_reg = 8'b11110111;
            3'b100: an_reg = 8'b11101111;
            3'b101: an_reg = 8'b11011111;
            3'b110: an_reg = 8'b10111111;
            3'b111: an_reg = 8'b01111111;
            default: an_reg = 8'b11111111;
        endcase
    end
    assign AN = an_reg;
    assign DP = 1'b1; // Decimal point off

endmodule

