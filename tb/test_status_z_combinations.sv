// ============================================================================
// Module: test_status_z_combinations
// Description: Concurrent assertions that verify the status bits are consistent
//              with the Z output.
// ============================================================================

module test_status_z_combinations(
    input logic        clk,
    input logic [7:0]  status,
    input logic [31:0] result,
    input logic [31:0] a,
    input logic [31:0] b
);

    // Unpack the status bits
    logic zero_f, inf_f, nan_f, huge_f;
    assign zero_f = status[0];
    assign inf_f  = status[1];
    assign nan_f  = status[2];
    assign huge_f = status[4];

    // Rule 1: Zero status means Exponent of Z is all 0s
    property p_zero_exp;
        @(posedge clk) zero_f |-> (result[30:23] == 8'h00);
    endproperty
    assert_zero_exp: assert property(p_zero_exp)
        else $error("SVA VIOLATION: Zero flag is high, but Z exponent is not 0.");

    // Rule 2: Infinity status means Exponent of Z is all 1s
    property p_inf_exp;
        @(posedge clk) inf_f |-> (result[30:23] == 8'hFF);
    endproperty
    assert_inf_exp: assert property(p_inf_exp)
        else $error("SVA VIOLATION: Inf flag is high, but Z exponent is not all 1s.");

    // Rule 3: NaN status means 2 cycles ago inputs were opposite sign Infinities/NaNs
    property p_nan_past;
        @(posedge clk) nan_f |-> $past(a[30:23] == 8'hFF && b[30:23] == 8'hFF && a[31] != b[31], 2);
    endproperty
    assert_nan_past: assert property(p_nan_past)
        else $error("SVA VIOLATION: NaN flag is high, but inputs 2 cycles ago were not opposite-sign Inf/NaNs.");

    // Rule 4: Huge status means Z is Infinity OR maxNormal
    property p_huge_val;
        @(posedge clk) huge_f |-> (result[30:23] == 8'hFF) || 
                                  (result[30:23] == 8'hFE && result[22:0] == 23'h7FFFFF);
    endproperty
    assert_huge_val: assert property(p_huge_val)
        else $error("SVA VIOLATION: Huge flag is high, but Z is neither Inf nor maxNormal.");

endmodule