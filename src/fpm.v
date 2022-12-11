`timescale 1ns / 1ps

module fpm(
  input clk,
  input rst,
  input [31:0] number_in,
  input number_a_valid,
  output number_a_ready,
  input number_b_valid,
  output number_b_ready,
  output [31:0] number_out,
  output result_valid
);

  reg reg_a_ready, reg_b_ready;
  reg a_sign, b_sign, z_sign;
  reg signed [9:0] a_exp, b_exp, z_exp;
  reg [23:0] a_mant, b_mant, z_mant;

  reg [47:0] product;

  reg reg_done;
  reg [31:0] result;

  reg [2:0] state;
  parameter READ_A = 0,
            READ_B = 1,
            DECODE = 2,
            MULTIPLY = 3,
            NORMALIZE = 4,
            ROUND = 5,
            PACK = 6,
            OUTPUT = 7;

  assign number_a_ready = reg_a_ready;
  assign number_b_ready = reg_b_ready;
  assign result_valid = reg_done;
  assign number_out = result;

  always@(posedge clk)
  begin
    case (state)
      READ_A: begin
        reg_a_ready <= 1;
        if (number_a_valid) begin
          reg_done <= 0;
          result <= 0;

          a_sign <= number_in[31];
          a_exp <= number_in[30:23] - 127;
          a_mant <= {1'b0, number_in[22:0]};

          reg_a_ready <= 0;
          state <= READ_B;
        end
      end

      READ_B: begin
        reg_b_ready <= 1;
        if (number_b_valid) begin
          b_sign <= number_in[31];
          b_exp <= number_in[30:23] - 127;
          b_mant <= {1'b0, number_in[22:0]};

          reg_b_ready <= 0;
          state <= DECODE;
        end
      end

      DECODE: begin
        // NaN * x = NaN
        if ((a_exp == 128 && a_mant != 0) || (b_exp == 128 && b_mant != 0)) begin
          z_sign <= 0;
          z_exp <= 255;
          z_mant[22] <= 1;
          z_mant[21:0] <= 0;
          state <= OUTPUT;
        // se a == inf
        end else if (a_exp == 128) begin
          z_sign <= a_sign ^ b_sign;
          z_exp <= 255;
          // inf * 0 = NaN
          if ((b_exp == -127) && (b_mant == 0)) begin
            z_mant[22] <= 1;
            z_mant[21:0] <= 0;
          // inf * x = inf
          end else begin
            z_mant <= 0;
          end
          state <= OUTPUT;
        // se b == inf
        end else if (b_exp == 128) begin
          z_sign <= a_sign ^ b_sign;
          z_exp <= 255;
          // 0 * inf = NaN
          if ((a_exp == -127) && (a_mant == 0)) begin
            z_mant[22] <= 1;
            z_mant[21:0] <= 0;
          // x * inf = inf
          end else begin
            z_mant <= 0;
          end
          state <= OUTPUT;
        // 0 * x = 0 con x != inf perchè verificato precedentemente
        end else if (((a_exp == -127) && (a_mant == 0)) || ((b_exp == -127) && (b_mant == 0))) begin
          z_sign <= a_sign ^ b_sign;
          z_exp <= 0;
          z_mant <= 0;
          state <= OUTPUT;
        end else begin
          // a e' in forma denormalizzata
          if (a_exp == -127) begin
            a_exp <= -126;
          end else begin
            a_mant[23] <= 1;
          end
          // b e' in forma denormalizzata
          if (b_exp == -127) begin
            b_exp <= -126;
          end else begin
            b_mant[23] <= 1;
          end

          state <= MULTIPLY;
        end
      end

      MULTIPLY: begin
        z_sign <= a_sign ^ b_sign;
        z_exp <= a_exp + b_exp + 1;
        product <= a_mant * b_mant;

        state <= NORMALIZE;
      end

      NORMALIZE: begin
        // rappresento i numeri con esponente minore di -126 in forma de-normalizzata
        // potrebbe verificarsi underflow che verra' gestito in seguito
        if (z_exp < -126 && z_exp > -130) begin
          product <= product >> 1;
          z_exp <= z_exp + 1;
          state <= NORMALIZE;
        // normalizzo il numero avendo l'accortezza di mantenere l'esponenete maggiore o uguale a -126
        end else if (product[47] == 0 && z_exp > -126) begin
          product <= product << 1;
          z_exp <= z_exp - 1;
          state <= NORMALIZE;
        end else begin
          state <= ROUND;
        end
      end

      ROUND: begin
        // se cado nel mezzo arrotondo al numero pari piu' vicino
        // altrimenti arrotondo al numero piu' vicino
        if (product[23] && (product[24] | product[22:0] != 0)) begin
          z_mant <= product[47:24] + 1; // arrotondo verso infinito
          // aumento l'esponente se la mantissa arrotondata risulta pari a 10.0
          if (product[47:24] == 24'hffffff) begin
            z_exp <= z_exp + 1;
          end
        end else begin
          z_mant <= product[47:24]; // arrotondo verso lo 0
        end
        state <= PACK;
      end

      PACK: begin
        if (z_exp > 128) begin // overflow
          z_mant <= 0;
          z_exp <= 255;
        end else if (z_exp < -126) begin // underflow
          z_mant <= 0;
          z_exp <= 0;
        end else if (z_mant[23] == 0 && z_exp == -126) begin // subnormal
          z_exp <= 0;
        end else begin // normal
          z_exp <= z_exp + 127;
        end
        state <= OUTPUT;
      end

      OUTPUT: begin
        reg_done <= 1;
        result[31] <= z_sign;
        result[30:23] <= z_exp;
        result[22:0] <= z_mant[22:0];
        state <= READ_A;
      end
    endcase

    if (rst == 0) begin
      reg_a_ready <= 0;
      reg_b_ready <= 0;
      reg_done <= 0;
      result <= 0;
      state <= READ_A;
    end
  end
endmodule
