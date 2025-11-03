// sobel_filter.v
// Sobel edge detection module - simplified load-then-process
module sobel_filter #(
    parameter WIDTH = 8,
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] pixel_in,
    output reg [WIDTH-1:0] pixel_out,
    output reg valid_out,
    output reg done
);

    // Image memory - store entire image
    reg [WIDTH-1:0] image_mem [0:IMG_HEIGHT*IMG_WIDTH-1];
    
    // Counters
    reg [19:0] load_addr;
    reg [15:0] proc_row, proc_col;
    
    // State machine
    reg [1:0] state;
    localparam IDLE = 0, LOAD = 1, COMPUTE = 2, DONE_STATE = 3;
    
    // 3x3 window
    reg [WIDTH-1:0] w00, w01, w02;
    reg [WIDTH-1:0] w10, w11, w12;
    reg [WIDTH-1:0] w20, w21, w22;
    
    // Sobel computation
    reg signed [WIDTH+10:0] Gx, Gy;
    reg [WIDTH+10:0] mag;
    
    // Helper for 2D indexing
    function [19:0] idx;
        input [15:0] row, col;
        begin
            idx = row * IMG_WIDTH + col;
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_addr <= 0;
            proc_row <= 0;
            proc_col <= 0;
            valid_out <= 0;
            done <= 0;
            pixel_out <= 0;
        end else begin
            valid_out <= 0;  // Default
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                        load_addr <= 0;
                        proc_row <= 0;
                        proc_col <= 0;
                    end
                end
                
                LOAD: begin
                    // Store incoming pixel
                    image_mem[load_addr] <= pixel_in;
                    load_addr <= load_addr + 1;
                    
                    // Check if all pixels loaded
                    if (load_addr == IMG_HEIGHT * IMG_WIDTH - 1) begin
                        state <= COMPUTE;
                        proc_row <= 0;
                        proc_col <= 0;
                    end
                end
                
                COMPUTE: begin
                    if (proc_row < IMG_HEIGHT - 2) begin
                        if (proc_col < IMG_WIDTH - 2) begin
                            // Load 3x3 window from memory
                            w00 <= image_mem[idx(proc_row,   proc_col)];
                            w01 <= image_mem[idx(proc_row,   proc_col+1)];
                            w02 <= image_mem[idx(proc_row,   proc_col+2)];
                            w10 <= image_mem[idx(proc_row+1, proc_col)];
                            w11 <= image_mem[idx(proc_row+1, proc_col+1)];
                            w12 <= image_mem[idx(proc_row+1, proc_col+2)];
                            w20 <= image_mem[idx(proc_row+2, proc_col)];
                            w21 <= image_mem[idx(proc_row+2, proc_col+1)];
                            w22 <= image_mem[idx(proc_row+2, proc_col+2)];
                            
                            // Compute Sobel gradients
                            // Gx kernel: [[-1,0,1],[-2,0,2],[-1,0,1]]
                            Gx = ($signed({1'b0, w02}) + 2*$signed({1'b0, w12}) + $signed({1'b0, w22})) -
                                 ($signed({1'b0, w00}) + 2*$signed({1'b0, w10}) + $signed({1'b0, w20}));
                            
                            // Gy kernel: [[1,2,1],[0,0,0],[-1,-2,-1]]
                            Gy = ($signed({1'b0, w00}) + 2*$signed({1'b0, w01}) + $signed({1'b0, w02})) -
                                 ($signed({1'b0, w20}) + 2*$signed({1'b0, w21}) + $signed({1'b0, w22}));
                            
                            // Magnitude: |Gx| + |Gy|
                            mag = (Gx[WIDTH+10] ? -Gx : Gx) + (Gy[WIDTH+10] ? -Gy : Gy);
                            
                            // Saturate to 8-bit and output
                            pixel_out <= (mag > 255) ? 8'd255 : mag[7:0];
                            valid_out <= 1;
                            
                            proc_col <= proc_col + 1;
                        end else begin
                            // Move to next row
                            proc_col <= 0;
                            proc_row <= proc_row + 1;
                        end
                    end else begin
                        // All rows processed
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
