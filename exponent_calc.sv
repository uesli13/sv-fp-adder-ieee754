// ============================================================================
// Module: exponent_calc
// Description: Compares the 8-bit exponents of the two floating-point operands.
//              Outputs the larger exponent, the absolute difference between 
//              them, and a flag indicating which operand had the larger exponent.
// ============================================================================

module exponent_calc(
    input  logic [7:0] Ea, Eb,
    output logic [7:0] max_exp,
    output logic [8:0] exp_diff,
    output logic       sign_exp_diff
);

    always_comb begin: calculate_difference
        // Case exponent of a is greater or equal to the exponent of b
        // When Ea == Eb, we choose A as "larger"
        if(Ea >= Eb) begin
            max_exp = Ea;
            exp_diff = 9'(Ea) - 9'(Eb);
            sign_exp_diff = 1'b1;
        end
        // Case exponent of b is greater than the exponent of a
        else begin
            max_exp = Eb;
            exp_diff = 9'(Eb) - 9'(Ea);
            sign_exp_diff = 1'b0;
        end
    end
endmodule