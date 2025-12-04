`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2025 08:18:08 PM
// Design Name: 
// Module Name: simple_i2c_master
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


//module simple_i2c_master(

// simple_i2c_master.v
module simple_i2c_master #(
    parameter CLK_FREQ = 100_000_000,
    parameter I2C_FREQ = 100_000
)(
    input  wire clk,
    input  wire resetn,
    input  wire start,
    output reg  busy,

    input  wire [6:0] addr,
    input  wire [7:0] reg_addr,
    input  wire [7:0] reg_data,

    output reg  scl,
    inout  wire sda
);
    localparam DIV = CLK_FREQ / (I2C_FREQ * 4); // 4 phases per SCL

    reg [15:0] cnt = 0;
    reg [5:0]  bit_cnt = 0;
    reg        sda_out = 1'b1;
    reg        sda_oe  = 1'b0; // 0 = hi-z (input / pull-up), 1 = drive

    assign sda = sda_oe ? sda_out : 1'bz;

    localparam ST_IDLE  = 3'd0;
    localparam ST_START = 3'd1;
    localparam ST_BITS  = 3'd2;
    localparam ST_STOP  = 3'd3;
    reg [2:0] state = ST_IDLE;

    reg [23:0] shifter; // [ADDR+W, REG, DATA]

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= ST_IDLE;
            scl     <= 1'b1;
            sda_out <= 1'b1;
            sda_oe  <= 1'b0;
            busy    <= 1'b0;
            cnt     <= 0;
            bit_cnt <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    scl     <= 1'b1;
                    sda_out <= 1'b1;
                    sda_oe  <= 1'b0;
                    busy    <= 1'b0;
                    if (start) begin
                        // prepare bytes: [ADDR+W, REG_ADDR, REG_DATA]
                        shifter <= {addr, 1'b0, reg_addr, reg_data};
                        bit_cnt <= 0;
                        busy    <= 1'b1;
                        state   <= ST_START;
                    end
                end

                ST_START: begin
                    // Start condition: SDA goes low while SCL high
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;
                    scl     <= 1'b1;
                    if (cnt < DIV) cnt <= cnt + 1;
                    else begin
                        cnt   <= 0;
                        state <= ST_BITS;
                    end
                end

                ST_BITS: begin
                    // Four phases per bit: SCL low setup, SCL high sample, SCL low hold, ACK (ignored)
                    if (cnt < DIV) begin
                        cnt <= cnt + 1;
                    end else begin
                        cnt <= 0;
                        // Toggle SCL
                        scl <= ~scl;

                        if (!scl) begin
                            // SCL just went low → set up next bit
                            if (bit_cnt < 24) begin
                                sda_oe  <= 1'b1;
                                sda_out <= shifter[23];
                                shifter <= {shifter[22:0], 1'b0};
                                bit_cnt <= bit_cnt + 1;
                            end else begin
                                // after all bits, send stop
                                state <= ST_STOP;
                            end
                        end else begin
                            // SCL high: data is valid; ignore ACK for simplicity
                        end
                    end
                end

                ST_STOP: begin
                    // Stop condition: SDA goes high while SCL high
                    scl     <= 1'b1;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;
                    if (cnt < DIV) cnt <= cnt + 1;
                    else begin
                        sda_out <= 1'b1;
                        state   <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

