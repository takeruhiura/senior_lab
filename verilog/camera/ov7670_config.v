`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2025 08:16:49 PM
// Design Name: 
// Module Name: ov7670_config
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//module ov7670_config(
// ov7670_config.v
// Minimal SCCB (I2C) initialization sequence for OV7670 example.
// Assumes 100 MHz clk, generates ~100 kHz SCL.

module ov7670_config (
    input  wire clk,
    input  wire resetn,
    output wire scl,
    inout  wire sda,
    output reg  config_done
);
    localparam I2C_ADDR = 7'h42 >> 1; // OV7670 write address 0x42 (8-bit) → 7-bit = 0x21

    // Example register list: {reg, value}
    // You will likely want to replace/extend this using a known working register set.
    localparam NUM_REGS = 6;
    reg [15:0] reg_seq [0:NUM_REGS-1];

    initial begin
        // {register, value}
        reg_seq[0] = {8'h12, 8'h80}; // COM7: reset
        reg_seq[1] = {8'h12, 8'h14}; // COM7: QVGA, RGB
        reg_seq[2] = {8'h11, 8'h01}; // CLKRC: prescaler
        reg_seq[3] = {8'h6B, 8'h0A}; // PLL
        reg_seq[4] = {8'h0C, 8'h00}; // COM3
        reg_seq[5] = {8'h3E, 8'h00}; // COM14
        // (Add more registers as needed)
    end

    reg [7:0] cur_reg;
    reg [7:0] cur_val;
    reg [7:0] idx = 0;

    reg        start = 0;
    wire       busy;
    reg        next  = 0;

    simple_i2c_master #(
        .CLK_FREQ(100_000_000),
        .I2C_FREQ(100_000)
    ) u_i2c (
        .clk   (clk),
        .resetn(resetn),
        .start (start),
        .busy  (busy),
        .addr  (I2C_ADDR),
        .reg_addr(cur_reg),
        .reg_data(cur_val),
        .scl   (scl),
        .sda   (sda)
    );

    localparam S_IDLE  = 2'd0;
    localparam S_LOAD  = 2'd1;
    localparam S_WAIT  = 2'd2;
    reg [1:0] state = S_IDLE;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state       <= S_IDLE;
            idx         <= 0;
            start       <= 0;
            config_done <= 0;
        end else begin
            start <= 0;
            case (state)
                S_IDLE: begin
                    if (!config_done) begin
                        cur_reg <= reg_seq[idx][15:8];
                        cur_val <= reg_seq[idx][7:0];
                        state   <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (!busy) begin
                        start <= 1;
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (!busy) begin
                        // Done with this register
                        if (idx == NUM_REGS-1) begin
                            config_done <= 1;
                            state       <= S_IDLE;
                        end else begin
                            idx   <= idx + 1;
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule

