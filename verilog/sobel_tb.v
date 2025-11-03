// sobel_tb.v
// Testbench for Sobel filter - reads PGM image file
`timescale 1ns/1ps

module sobel_tb;
    parameter WIDTH = 8;
    parameter MAX_SIZE = 1024;  // Maximum image dimension (supports up to 1024x1024)
    
    reg clk;
    reg rst_n;
    reg start;
    reg [WIDTH-1:0] pixel_in;
    wire [WIDTH-1:0] pixel_out;
    wire valid_out;
    wire done;
    
    // Image parameters (read from file)
    integer IMG_WIDTH;
    integer IMG_HEIGHT;
    
    // Image storage
    reg [WIDTH-1:0] input_image [0:MAX_SIZE*MAX_SIZE-1];
    reg [WIDTH-1:0] output_image [0:MAX_SIZE*MAX_SIZE-1];
    
    integer i, j, pixel_idx, out_idx;
    integer in_file, out_file, scan_result;
    integer max_val;
    reg [8*10:0] format_type;
    
    // Instantiate module (will be configured after reading image)
    sobel_filter #(
        .WIDTH(WIDTH),
        .IMG_WIDTH(256),  // Default, will be overridden
        .IMG_HEIGHT(256)
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
        pixel_idx = 0;
        out_idx = 0;
        
        // Read PGM file
        in_file = $fopen("input_image.pgm", "r");
        if (in_file == 0) begin
            $display("ERROR: Cannot open input_image.pgm");
            $display("Please create input_image.pgm using the Python script:");
            $display("  python image_to_pgm.py your_image.jpg");
            $finish;
        end
        
        // Read PGM header
        scan_result = $fscanf(in_file, "%s\n", format_type);
        if (format_type != "P2") begin
            $display("ERROR: Only P2 (ASCII) PGM format supported");
            $fclose(in_file);
            $finish;
        end
        
        scan_result = $fscanf(in_file, "%d %d\n", IMG_WIDTH, IMG_HEIGHT);
        scan_result = $fscanf(in_file, "%d\n", max_val);
        
        $display("Reading PGM image:");
        $display("  Format: P2 (ASCII PGM)");
        $display("  Dimensions: %0d x %0d", IMG_WIDTH, IMG_HEIGHT);
        $display("  Max value: %0d", max_val);
        
        if (IMG_WIDTH > MAX_SIZE || IMG_HEIGHT > MAX_SIZE) begin
            $display("ERROR: Image too large! Max size is %0d x %0d", MAX_SIZE, MAX_SIZE);
            $fclose(in_file);
            $finish;
        end
        
        // Read pixel data
        for (i = 0; i < IMG_HEIGHT * IMG_WIDTH; i = i + 1) begin
            scan_result = $fscanf(in_file, "%d", input_image[i]);
        end
        $fclose(in_file);
        
        $display("Image loaded successfully!");
        
        // Reset and start
        #20 rst_n = 1;
        #10 start = 1;
        #10 start = 0;
        
        // Feed input pixels
        for (i = 0; i < IMG_HEIGHT * IMG_WIDTH; i = i + 1) begin
            @(posedge clk);
            pixel_in = input_image[i];
        end
        
        // Collect output in parallel
        fork
            // Process to collect output pixels
            begin
                while (!done) begin
                    @(posedge clk);
                    if (valid_out) begin
                        output_image[out_idx] = pixel_out;
                        out_idx = out_idx + 1;
                    end
                end
            end
        join
        
        // Wait a bit after done
        #100;
        
        // Save output as PGM
        out_file = $fopen("output_image.pgm", "w");
        $fwrite(out_file, "P2\n");
        $fwrite(out_file, "%0d %0d\n", IMG_WIDTH-2, IMG_HEIGHT-2);
        $fwrite(out_file, "255\n");
        
        for (i = 0; i < (IMG_HEIGHT-2) * (IMG_WIDTH-2); i = i + 1) begin
            $fwrite(out_file, "%0d ", output_image[i]);
            if ((i + 1) % (IMG_WIDTH-2) == 0)
                $fwrite(out_file, "\n");
        end
        $fclose(out_file);
        
        $display("Sobel filter complete!");
        $display("Output saved to: output_image.pgm");
        $display("Output dimensions: %0d x %0d", IMG_WIDTH-2, IMG_HEIGHT-2);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000000;
        $display("ERROR: Timeout!");
        $finish;
    end
endmodule
