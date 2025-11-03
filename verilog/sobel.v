// sobel_filter.v
// Sobel edge detection module
module sobel_filter #(
    parameter WIDTH = 8,
    parameter IMG_WIDTH = 256,
    parameter IMG_HEIGHT = 256
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] pixel_in,
    output reg [WIDTH-1:0] pixel_out,
    output reg valid_out,
    output reg done
);

    // 3x3 window buffer
    reg [WIDTH-1:0] window [0:2][0:2];
    
    // Counters
    reg [15:0] row_cnt;
    reg [15:0] col_cnt;
    reg [15:0] out_row;
    reg [15:0] out_col;
    
    // State machine
    reg [2:0] state;
    localparam IDLE = 0, LOAD = 1, COMPUTE = 2, DONE = 3;
    
    // Sobel gradients
    reg signed [WIDTH+10:0] Gx, Gy;
    reg [WIDTH+10:0] magnitude;
    
    // Line buffers for 3 rows
    reg [WIDTH-1:0] line_buf0 [0:IMG_WIDTH-1];
    reg [WIDTH-1:0] line_buf1 [0:IMG_WIDTH-1];
    reg [WIDTH-1:0] line_buf2 [0:IMG_WIDTH-1];
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_cnt <= 0;
            col_cnt <= 0;
            out_row <= 0;
            out_col <= 0;
            valid_out <= 0;
            done <= 0;
            for (i = 0; i < 3; i = i + 1)
                for (j = 0; j < 3; j = j + 1)
                    window[i][j] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid_out <= 0;
                    if (start) begin
                        state <= LOAD;
                        row_cnt <= 0;
                        col_cnt <= 0;
                        out_row <= 0;
                        out_col <= 0;
                    end
                end
                
                LOAD: begin
                    // Store pixel in appropriate line buffer
                    if (row_cnt == 0)
                        line_buf0[col_cnt] <= pixel_in;
                    else if (row_cnt == 1)
                        line_buf1[col_cnt] <= pixel_in;
                    else
                        line_buf2[col_cnt] <= pixel_in;
                    
                    // Update counters
                    if (col_cnt == IMG_WIDTH - 1) begin
                        col_cnt <= 0;
                        if (row_cnt == IMG_HEIGHT - 1) begin
                            state <= COMPUTE;
                            out_row <= 0;
                            out_col <= 0;
                        end else begin
                            row_cnt <= row_cnt + 1;
                        end
                    end else begin
                        col_cnt <= col_cnt + 1;
                    end
                end
                
                COMPUTE: begin
                    // Load 3x3 window
                    if (out_col < IMG_WIDTH - 2) begin
                        window[0][0] <= line_buf0[out_col];
                        window[0][1] <= line_buf0[out_col + 1];
                        window[0][2] <= line_buf0[out_col + 2];
                        window[1][0] <= line_buf1[out_col];
                        window[1][1] <= line_buf1[out_col + 1];
                        window[1][2] <= line_buf1[out_col + 2];
                        window[2][0] <= line_buf2[out_col];
                        window[2][1] <= line_buf2[out_col + 1];
                        window[2][2] <= line_buf2[out_col + 2];
                        
                        // Compute Sobel gradients
                        Gx = (2*$signed({1'b0, window[2][1]}) + $signed({1'b0, window[2][0]}) + $signed({1'b0, window[2][2]})) -
                             (2*$signed({1'b0, window[0][1]}) + $signed({1'b0, window[0][0]}) + $signed({1'b0, window[0][2]}));
                        
                        Gy = (2*$signed({1'b0, window[1][2]}) + $signed({1'b0, window[0][2]}) + $signed({1'b0, window[2][2]})) -
                             (2*$signed({1'b0, window[1][0]}) + $signed({1'b0, window[0][0]}) + $signed({1'b0, window[2][0]}));
                        
                        // Approximate magnitude (|Gx| + |Gy|) for hardware efficiency
                        magnitude = (Gx[WIDTH+10] ? -Gx : Gx) + (Gy[WIDTH+10] ? -Gy : Gy);
                        
                        // Saturate to 8-bit
                        pixel_out <= (magnitude > 255) ? 8'd255 : magnitude[7:0];
                        valid_out <= 1;
                        
                        // Update position
                        if (out_col == IMG_WIDTH - 3) begin
                            out_col <= 0;
                            if (out_row == IMG_HEIGHT - 3) begin
                                state <= DONE;
                            end else begin
                                out_row <= out_row + 1;
                            end
                        end else begin
                            out_col <= out_col + 1;
                        end
                    end
                end
                
                DONE: begin
                    valid_out <= 0;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule