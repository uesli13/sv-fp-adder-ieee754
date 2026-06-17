// ============================================================================
// Module: fp_adder
// Description: Main combinational core of the 32-bit single-precision 
//              floating-point adder. It coordinates the data path through 
//              sign calculation, exponent comparison, mantissa addition, 
//              normalization, rounding, and exception handling to produce 
//              the final 32-bit result and an 8-bit status flag.
// ============================================================================
import round_pkg::*;

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


    // =========================================================================
    // Sign Calculation
    // =========================================================================

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
                    //If mantissas are also equal the result will be 0 and the sign positive (0)
                    z_sign  = 1'b0;
                end
            end
        end
    end


    // =========================================================================
    // Internal Wires for Sub-Modules
    // =========================================================================

    // Exponent Calculator wires
    logic [7:0] max_exp;
    logic [8:0] exp_diff;
    logic       sign_exp_diff;

    // Mantissa Calulator wires
    logic [27:0] result_mant;

    // Normalization Module wires
    logic [8:0]  norm_exp;
    logic [26:0] norm_mant;

    // Rounding Module Wires
    logic [24:0] round_mant;
    logic        inexact_bit;

    // Post-Round Normalization wires
    logic [31:0] z_calc;
    logic [22:0] final_mant;
    logic [8:0]  post_norm_exp;
    logic        overflow;
    logic        underflow;

    // Exception Handling flag wires
    logic zero_f;
    logic inf_f;
    logic nan_f;
    logic tiny_f;
    logic huge_f;
    logic inexact_f;


    // =========================================================================
    // Module Instantiations
    // =========================================================================
    
    // Exponent Calculator
    exponent_calc u_exponent_calc(
        .Ea            (float_a.exp),
        .Eb            (float_b.exp),
        .max_exp       (max_exp),
        .exp_diff      (exp_diff),
        .sign_exp_diff (sign_exp_diff)
    );

    // Mantissa Calulator
    mant_calc u_mant_calc(
        .exp_diff      (exp_diff),
        .mant_a        ({1'b1, float_a.mant}), // plus the hidden bit
        .mant_b        ({1'b1, float_b.mant}),
        .sign_exp_diff (sign_exp_diff),
        .sa            (float_a.sign),
        .sb            (float_b.sign),
        .result_mant   (result_mant)
    );

    // Normalization Module
    norm_adder u_norm_adder(
        .max_exp     (max_exp),
        .result_mant (result_mant),
        .norm_exp    (norm_exp),
        .norm_mant   (norm_mant) 
    );

    // Rounding Module
    round_adder u_round_adder(
        .round       (round),
        .norm_mant   (norm_mant),
        .z_sign      (z_sign),
        .round_mant  (round_mant),
        .inexact_bit (inexact_bit)
    );

    // Exeption Handler
    exception_adder u_exception_adder(
    .a           (a),
    .b           (b),
    .round       (round),
    .z_calc      (z_calc),
    .overflow    (overflow),
    .underflow   (underflow),
    .inexact_bit (inexact_bit),
    .result      (result),
    .zero_f      (zero_f),
    .inf_f       (inf_f),
    .nan_f       (nan_f),
    .tiny_f      (tiny_f),
    .huge_f      (huge_f),
    .inexact_f   (inexact_f)
);


    // =========================================================================
    // Post-Round Normalization
    // =========================================================================
    // Purpose: Handle rounding overflow, detect overflow/underflow conditions,
    //          and create z_calc intermediate result
    //
    // Inputs:  logic [24:0] round_mant
    //          logic [8:0]  norm_exp
    //          logic [0:0]  z_sign
    //
    // Outputs: logic [31:0] z_calc
    //          logic        overflow
    //          logic        underflow

    always_comb begin : post_round_norm
        
        // Default values
        final_mant    = 23'b0;
        post_norm_exp = norm_exp;
        overflow      = 1'b0;
        underflow     = 1'b0;

        // Handle Mantissa Carry-Out
        if(round_mant[24] == 1'b1) begin
            final_mant    = round_mant[23:1];
            post_norm_exp = norm_exp + 9'b1;
        end
        else begin
            final_mant    = round_mant[22:0];
            post_norm_exp = norm_exp;
        end

        // Overflow check
        if(post_norm_exp > 9'd255) begin
            overflow = 1'b1;
        end

        // Underflow check
        if(post_norm_exp == 9'd0) begin
            underflow = 1'b1;
        end

        // Create final z_calc
        z_calc = {z_sign, post_norm_exp[7:0], final_mant};

    end


    // =========================================================================
    // Status Output Assembly
    // =========================================================================

    assign status = {2'b0, inexact_f, huge_f, tiny_f, nan_f, inf_f, zero_f};

endmodule