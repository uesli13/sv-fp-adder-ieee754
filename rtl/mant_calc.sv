// ============================================================================
// Module:      mant_calc
// Description: Aligns the mantissas based on exponent difference, extracts 
//              Guard, Round, and Sticky (GRS) bits, and performs the final 
//              addition or subtraction of the 27-bit aligned mantissas.
// ============================================================================

module mant_calc(
    input  logic [8:0]  exp_diff,
    input  logic [23:0] mant_a, mant_b,
    input  logic        sign_exp_diff,
    input  logic        sa, sb,
    output logic [27:0] result_mant
);

    // Internal Signals
    logic [23:0] small_mant, large_mant;
    logic [48:0] small_mant_49;
    logic [26:0] small_mant_27, large_mant_27;
    logic G, R, S; // Guard, Round, and Sticky bits

    // Route the inputs to small and large wires before processing
    always_comb begin
        if(exp_diff == 9'b0) begin // Ea == Eb
            if(mant_a >= mant_b) begin
                small_mant = mant_b;
                large_mant = mant_a;
            end
            else begin
                small_mant = mant_a;
                large_mant = mant_b;
            end
        end
        else begin // Ea != Eb
            if(sign_exp_diff==1'b1) begin // Ea > Eb
                small_mant = mant_b;
                large_mant = mant_a;
            end
            else begin // Ea < Eb
                small_mant = mant_a;
                large_mant = mant_b;
            end
        end
    end
    
    // Alignment, GRS Extraction, and Arithmetic
    always_comb begin
        // Shift to align the binary point
        small_mant_49 = {small_mant, 25'b0} >> exp_diff;

        // Extract GRS bits
        G = small_mant_49[24];
        R = small_mant_49[23];

        if(exp_diff > 48) begin
            S = 1'b1;
        end
        else begin
            S = | small_mant_49[22:0];
        end

        // Pack into 27 bits
        small_mant_27 = {small_mant_49[48:25] ,G,R,S};
        large_mant_27 = {large_mant, 3'b0};

        // Perform final Add/Sub
        if(sa == sb) begin
            result_mant = 28'(small_mant_27) + 28'(large_mant_27);
        end
        else begin
            result_mant = 28'(large_mant_27) - 28'(small_mant_27);
        end
    end
endmodule