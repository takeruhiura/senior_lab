// sobel_filter.v
// Sobel edge detection module with streaming architecture
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

    // Line buffers for 3 rows
    reg [WIDTH-1:0] line0 [0:IMG_WIDTH-1];
    reg [WIDTH-1:0] line1 [0:IMG_WIDTH-1];
    reg [WIDTH-1:0] line2 [0:IMG_WIDTH-1];
    
    // Counters
    reg [15:0] in_col, in_row;
    reg [15:0] out_col, out_row;
    
    // State machine
    reg [2:0] state;
    localparam IDLE = 0, LOAD_ROW0 = 1, LOAD_ROW1 = 2, PROCESS = 3, DONE_STATE = 4;
    
    // 3x3 window
    reg [WIDTH-1:0] w00, w01, w02;
    reg [WIDTH-1:0] w10, w11, w12;
    reg [WIDTH-1:0] w20, w21, w22;
    
    // Sobel computation
    reg signed [WIDTH+10:0] Gx, Gy;
    reg [WIDTH+10:0] mag;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            in_col <= 0;
            in_row <= 0;
            out_col <= 0;
            out_row <= 0;
            valid_out <= 0;
            done <= 0;
            pixel_out <= 0;
        end else begin
            valid_out <= 0;  // Default
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_ROW0;
                        in_col <= 0;
                        in_row <= 0;
                        out_col <= 0;
                        out_row <= 0;
                    end
                end
                
                LOAD_ROW0: begin
                    // Load first row into line0
                    line0[in_col] <= pixel_in;
                    
                    if (in_col == IMG_WIDTH - 1) begin
                        in_col <= 0;
                        state <= LOAD_ROW1;
                    end else begin
                        in_col <= in_col + 1;
                    end
                end
                
                LOAD_ROW1: begin
                    // Load second row into line1
                    line1[in_col] <= pixel_in;
                    
                    if (in_col == IMG_WIDTH - 1) begin
                        in_col <= 0;
                        in_row <= 2;
                        state <= PROCESS;
                    end else begin
                        in_col <= in_col + 1;
                    end
                end
                
                PROCESS: begin
                    // Load new pixel into line2
                    if (in_row < IMG_HEIGHT) begin
                        line2[in_col] <= pixel_in;
                        in_col <= in_col + 1;
                        
                        if (in_col == IMG_WIDTH - 1) begin
                            in_col <= 0;
                            in_row <= in_row + 1;
                        end
                    end
                    
                    // Compute Sobel for current window position
                    if (out_col < IMG_WIDTH - 2) begin
                        // Load 3x3 window
                        w00 <= line0[out_col];
                        w01 <= line0[out_col + 1];
                        w02 <= line0[out_col + 2];
                        w10 <= line1[out_col];
                        w11 <= line1[out_col + 1];
                        w12 <= line1[out_col + 2];
                        w20 <= line2[out_col];
                        w21 <= line2[out_col + 1];
                        w22 <= line2[out_col + 2];
                        
                        // Sobel Gx = [[-1,0,1],[-2,0,2],[-1,0,1]]
                        Gx = ($signed({1'b0, w02}) + 2*$signed({1'b0, w12}) + $signed({1'b0, w22})) -
                             ($signed({1'b0, w00}) + 2*$signed({1'b0, w10}) + $signed({1'b0, w20}));
                        
                        // Sobel Gy = [[1,2,1],[0,0,0],[-1,-2,-1]]
                        Gy = ($signed({1'b0, w00}) + 2*$signed({1'b0, w01}) + $signed({1'b0, w02})) -
                             ($signed({1'b0, w20}) + 2*$signed({1'b0, w21}) + $signed({1'b0, w22}));
                        
                        // Magnitude approximation: |Gx| + |Gy|
                        mag = (Gx[WIDTH+10] ? -Gx : Gx) + (Gy[WIDTH+10] ? -Gy : Gy);
                        
                        // Saturate and output
                        pixel_out <= (mag > 255) ? 8'd255 : mag[7:0];
                        valid_out <= 1;
                        
                        out_col <= out_col + 1;
                    end else if (out_row < IMG_HEIGHT - 3) begin
                        // Move to next row
                        out_col <= 0;
                        out_row <= out_row + 1;
                        
                        // Shift line buffers
                        for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                            line0[i] <= line1[i];
                            line1[i] <= line2[i];
                        end
                    end else begin
                        // Processing complete
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
