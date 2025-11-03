// sobel_tb.v
// Testbench for Sobel filter
`timescale 1ns/1ps

module sobel_tb;
    parameter WIDTH = 8;
    parameter IMG_WIDTH = 64;  // Small test image
    parameter IMG_HEIGHT = 64;
    
    reg clk;
    reg rst_n;
    reg start;
    reg [WIDTH-1:0] pixel_in;
    wire [WIDTH-1:0] pixel_out;
    wire valid_out;
    wire done;
    
    // Image storage
    reg [WIDTH-1:0] input_image [0:IMG_HEIGHT-1][0:IMG_WIDTH-1];
    reg [WIDTH-1:0] output_image [0:IMG_HEIGHT-3][0:IMG_WIDTH-3];
    
    integer i, j, out_i, out_j;
    integer in_file, out_file;
    
    // Instantiate module
    sobel_filter #(
        .WIDTH(WIDTH),
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .pixel_in(pixel_in),
        .pixel_out(pixel_out),
        .valid_out(valid_out),
        .done(done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test procedure
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        pixel_in = 0;
        out_i = 0;
        out_j = 0;
        
        // Create test image (gradient pattern)
        for (i = 0; i < IMG_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMG_WIDTH; j = j + 1) begin
                // Create a pattern: diagonal gradient + square
                if ((i > 20 && i < 40) && (j > 20 && j < 40))
                    input_image[i][j] = 255; // White square
                else
                    input_image[i][j] = (i + j) * 2; // Gradient
            end
        end
        
        // Save input image to file
        in_file = $fopen("input_image.txt", "w");
        for (i = 0; i < IMG_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMG_WIDTH; j = j + 1) begin
                $fwrite(in_file, "%3d ", input_image[i][j]);
            end
            $fwrite(in_file, "\n");
        end
        $fclose(in_file);
        
        // Reset
        #20 rst_n = 1;
        #10 start = 1;
        #10 start = 0;
        
        // Feed input pixels
        for (i = 0; i < IMG_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMG_WIDTH; j = j + 1) begin
                @(posedge clk);
                pixel_in = input_image[i][j];
            end
        end
        
        // Wait for processing and collect output
        fork
            begin
                wait(done);
                #100;
                
                // Save output image
                out_file = $fopen("output_image.txt", "w");
                for (i = 0; i < IMG_HEIGHT-2; i = i + 1) begin
                    for (j = 0; j < IMG_WIDTH-2; j = j + 1) begin
                        $fwrite(out_file, "%3d ", output_image[i][j]);
                    end
                    $fwrite(out_file, "\n");
                end
                $fclose(out_file);
                
                $display("Sobel filter complete!");
                $display("Input saved to: input_image.txt");
                $display("Output saved to: output_image.txt");
                $finish;
            end
            
            begin
                forever begin
                    @(posedge clk);
                    if (valid_out) begin
                        output_image[out_i][out_j] = pixel_out;
                        if (out_j == IMG_WIDTH - 3) begin
                            out_j = 0;
                            out_i = out_i + 1;
                        end else begin
                            out_j = out_j + 1;
                        end
                    end
                end
            end
        join_any
    end
    
    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Timeout!");
        $finish;
    end
endmodule