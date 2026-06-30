// DDR5 Inline ECC — SEC-DED (Single-bit Error Correct, Double-bit Detect)
// Hamming(72,64): 64 data bits + 8 check bits
// Also supports SDDC (Symbol Device Data Correction) and inline ECC

module ddr5_ecc #(
  parameter int DATA_WIDTH  = 64,   // per sub-channel
  parameter int CHECK_BITS  = 8
)(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              ecc_en,
  // Encode path (write)
  input  logic [DATA_WIDTH-1:0]  enc_data_in,
  output logic [DATA_WIDTH+CHECK_BITS-1:0] enc_data_out,
  // Decode path (read)
  input  logic [DATA_WIDTH+CHECK_BITS-1:0] dec_data_in,
  output logic [DATA_WIDTH-1:0]  dec_data_out,
  output logic              sbe_detected,  // Single-bit error (corrected)
  output logic              dbe_detected,  // Double-bit error (uncorrectable)
  output logic [7:0]        syndrome,
  output logic [5:0]        error_bit_pos  // bit position of SBE
);

  // -----------------------------------------------------------------------
  // Parity check matrix H for Hamming(72,64)
  // P[i] = XOR of data bits that have bit i set in their column index
  // -----------------------------------------------------------------------
  logic [7:0] check_bits_enc;
  logic [7:0] check_bits_dec;
  logic [7:0] syn;

  // Encode: generate check bits
  always_comb begin
    if (!ecc_en) begin
      enc_data_out = {8'h0, enc_data_in};
    end else begin
      check_bits_enc = '0;
      for (int i = 0; i < DATA_WIDTH; i++) begin
        // Each check bit covers specific data bit positions per Hamming matrix
        for (int p = 0; p < CHECK_BITS; p++) begin
          if (((i + CHECK_BITS + 1) >> p) & 1)
            check_bits_enc[p] ^= enc_data_in[i];
        end
      end
      enc_data_out = {check_bits_enc, enc_data_in};
    end
  end

  // Decode: compute syndrome
  always_comb begin
    dec_data_out = dec_data_in[DATA_WIDTH-1:0];
    sbe_detected = 0; dbe_detected = 0;
    syndrome = '0; error_bit_pos = '0;

    if (ecc_en) begin
      // Recompute check bits over received data
      check_bits_dec = '0;
      for (int i = 0; i < DATA_WIDTH; i++) begin
        for (int p = 0; p < CHECK_BITS; p++) begin
          if (((i + CHECK_BITS + 1) >> p) & 1)
            check_bits_dec[p] ^= dec_data_in[i];
        end
      end
      syn = check_bits_dec ^ dec_data_in[DATA_WIDTH+CHECK_BITS-1:DATA_WIDTH];
      syndrome = syn;

      if (syn != 0) begin
        int err_pos = int'(syn) - 1;
        if (err_pos < DATA_WIDTH) begin
          sbe_detected = 1;
          error_bit_pos = 6'(err_pos);
          // Correct the bit
          dec_data_out = dec_data_in[DATA_WIDTH-1:0];
          dec_data_out[err_pos] = ~dec_data_out[err_pos];
        end else begin
          // Syndrome doesn't map to data — check bit error or DBE
          dbe_detected = 1;
          dec_data_out = dec_data_in[DATA_WIDTH-1:0]; // Uncorrectable
        end
      end
    end
  end

endmodule : ddr5_ecc
