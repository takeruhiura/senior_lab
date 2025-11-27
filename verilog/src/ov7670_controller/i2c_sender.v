//////////////////////////////////////////////////////////////////////////////////
// Engineer: <mfield@concepts.co.nz
// 
// Description: Send the commands to the OV7670 over an I2C-like interface
//////////////////////////////////////////////////////////////////////////////////

module i2c_sender(
    input  wire        clk,
    inout  wire        siod,
    output reg         sioc,
    output reg         taken,
    input  wire        send,
    input  wire [7:0]  id,
    input  wire [7:0]  reg_addr,
    input  wire [7:0]  value
);

    // this value gives a 254 cycle pause before the initial frame is sent
    reg [7:0]  divider = 8'h01;
    reg [31:0] busy_sr = 32'h0;
    reg [31:0] data_sr = 32'hFFFFFFFF;
    
    assign siod = (busy_sr[11:10] == 2'b10 || 
                   busy_sr[20:19] == 2'b10 || 
                   busy_sr[29:28] == 2'b10) ? 1'bZ : data_sr[31];
    
    always @(posedge clk) begin
        taken <= 1'b0;
        if (busy_sr[31] == 1'b0) begin
            sioc <= 1'b1;
            if (send == 1'b1) begin
                if (divider == 8'h00) begin
                    data_sr <= {4'b100, id, 1'b0, reg_addr, 1'b0, value, 1'b0, 2'b01};
                    busy_sr <= {3'b111, 9'h1FF, 9'h1FF, 9'h1FF, 2'b11};
                    taken <= 1'b1;
                end else begin
                    divider <= divider + 1; // this only happens on powerup
                end
            end
        end else begin
            case ({busy_sr[31:29], busy_sr[2:0]})
                {3'b111, 3'b111}: begin // start seq #1
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b1;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b1;
                    endcase
                end
                {3'b111, 3'b110}: begin // start seq #2
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b1;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b1;
                    endcase
                end
                {3'b111, 3'b100}: begin // start seq #3
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b0;
                        2'b01:   sioc <= 1'b0;
                        2'b10:   sioc <= 1'b0;
                        default:  sioc <= 1'b0;
                    endcase
                end
                {3'b110, 3'b000}: begin // end seq #1
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b0;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b1;
                    endcase
                end
                {3'b100, 3'b000}: begin // end seq #2
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b1;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b1;
                    endcase
                end
                {3'b000, 3'b000}: begin // Idle
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b1;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b1;
                    endcase
                end
                default: begin
                    case (divider[7:6])
                        2'b00:   sioc <= 1'b0;
                        2'b01:   sioc <= 1'b1;
                        2'b10:   sioc <= 1'b1;
                        default:  sioc <= 1'b0;
                    endcase
                end
            endcase

            if (divider == 8'hFF) begin
                busy_sr <= {busy_sr[30:0], 1'b0};
                data_sr <= {data_sr[30:0], 1'b1};
                divider <= 8'h0;
            end else begin
                divider <= divider + 1;
            end
        end
    end
endmodule

