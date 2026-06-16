// ============================================================================
// Module: norm_adder
// Description: Normalizes the 28-bit mantissa by shifting it right (if overflow)
//              or left (if underflow), and adjusts the exponent accordingly.
// ============================================================================

module norm_adder(
    input  logic [7:0]  max_exp,
    input  logic [27:0] result_mant,
    output logic [8:0]  norm_exp,
    output logic [26:0] norm_mant 
);
    logic [4:0] zero_count;

    // Instantiate the Leading Zero Counter
    lzc u_lzc (
        .mant_in(result_mant),
        .zero_count(zero_count)
    );

    always_comb begin
        // Check for carry-out overflow from the addition
        if(result_mant[27] == 1'b1) begin
            // Shift right by 1, but OR the shifted-out bit into the new sticky bit
            norm_mant = {result_mant[27:2], result_mant[1] | result_mant[0]};
            norm_exp = 9'(max_exp) + 9'b1;
       end 
       // Otherwise, shift left by the number of leading zeros
       else begin
            // Subtract zero_count by 1 because Bit 27 is a always 0
            norm_mant = result_mant[26:0] << (zero_count - 1);
            norm_exp = 9'(max_exp) - 9'(zero_count - 1);
       end
    end
endmodule