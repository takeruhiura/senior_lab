`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2025 08:14:49 PM
// Design Name: 
// Module Name: uart_tx_module
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


//module uart_tx_module(

 // uart_tx_module.v
module uart_tx_module #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire resetn,
    input  wire [7:0] data_in,
    input  wire send,
    output reg  tx,
    output reg  busy
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    reg [15:0] clk_cnt = 16'd0;
    reg [3:0]  bit_idx = 4'd0;
    reg [9:0]  shifter = 10'b1111111111;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;
    reg [1:0] state = S_IDLE;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= S_IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            tx      <= 1'b1;
            busy    <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (send) begin
                        shifter <= {1'b1, data_in, 1'b0}; // stop, data, start
                        state   <= S_START;
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        busy    <= 1'b1;
                    end
                end

                S_START, S_DATA, S_STOP: begin
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 0;
                        tx <= shifter[bit_idx];
                        bit_idx <= bit_idx + 1'b1;

                        if (bit_idx == 4'd9) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_DATA;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

