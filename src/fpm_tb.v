`timescale 1ns / 1ps

module tb();

  reg clk, rst, read_a, read_b;
  reg [31:0] number;

  wire a_ready, b_ready, res_ready;
  wire [31:0] result;

  fpm dut(
    .clk(clk),
    .rst(rst),
    .number_in(number),
    .number_a_ready(a_ready),
    .number_a_valid(read_a),
    .number_b_ready(b_ready),
    .number_b_valid(read_b),
    .number_out(result),
    .result_valid(res_ready)
  );

  initial
  begin
    clk <= 1'b1;
    read_a <= 0;
    read_b <= 0;
    #10 rst <= 1'b0;
    #20 rst <= 1'b1;

    #20 number <= 32'b10111111100100010100100111111110; // -1.13507056236267
    read_a <= 1;
    #20 read_a <= 0;

    #20 number <= 32'b10111111111000011000100101100001; // -1.76200497150421
    read_b <= 1;
    #20 read_b <= 0;
  end

  always #10 clk <= !clk;

endmodule
