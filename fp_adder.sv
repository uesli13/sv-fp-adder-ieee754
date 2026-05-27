import round_pkg::*;

// ============================================================================
// Module: fp_adder
// Description:
// ============================================================================

module fp_adder(
    input  logic [31:0] a,b,    // 32-bit floating-point input operands
    input  round_mode_t round,  // 3-bit rounding mode selector
    output logic [31:0] result, // Final 32-bit floating-point result
    output logic [7:0]  status  // 8-bit status flags
);

    // Define the IEEE-754 Single-Precision format as a packed struct.
    typedef struct packed {
        logic        sign;
        logic [7:0]  exp;
        logic [22:0] mant;
    } float_t;

    float_t float_a, float_b; // Structured versions of operands a and b
    logic z_sign;             // Calculated sign of the final result (Z)

    // Cast the raw 32-bit inputs into our structured format
    assign float_a = a;
    assign float_b = b;

    // Sign calculation
    always_comb begin : sign_calculator
        //If operants have the same sign, the result keeps this sign
        if (float_a.sign == float_b.sign) begin
            z_sign = float_a.sign;
        end
        else begin
            //If operants have different signs, the result takes the largest magnitudes' sign

            //First compare the exponents 
            if (float_a.exp > float_b.exp) begin
                z_sign = float_a.sign;
            end
            else if (float_b.exp > float_a.exp) begin
                z_sign = float_b.sign;
            end
            else begin 
                // If the exponents are equal, compare the mantissas
                if(float_a.mant > float_b.mant) begin
                    z_sign = float_a.sign;
                end
                else if (float_b.mant > float_a.mant) begin
                    z_sign = float_b.sign;
                end
                else begin
                    //If mantissas are also equal the result will be 0 and the sign possitive (0)
                    z_sign  = 1'b0;
                end
            end
        end
    end
endmodule