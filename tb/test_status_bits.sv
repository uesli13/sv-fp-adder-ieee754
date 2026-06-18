// ============================================================================
// Module: test_status_bits
// Description: Immediate assertions that verify the status bits are consistent
//              with each other.
// ============================================================================

module test_status_bits(
    input logic resetn,
    input logic [7:0] status
);

    // Unpack the status bits
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    
    assign zero_f    = status[0];
    assign inf_f     = status[1];
    assign nan_f     = status[2];
    assign tiny_f    = status[3];
    assign huge_f    = status[4];
    assign inexact_f = status[5];

    //
    always_comb begin
        // Only evaluate assertions if the system is out of reset AND status is not floating
        if (resetn && !$isunknown(status)) begin

            assert_zero_not_inf: assert (!(zero_f && inf_f))
                else $error("SVA VIOLATION: Result cannot be Zero and Infinity!");

            assert_zero_not_nan: assert (!(zero_f && nan_f))
                else $error("SVA VIOLATION: Result cannot be Zero and NaN!");

            assert_inf_not_nan:  assert (!(inf_f && nan_f)) 
                else $error("SVA VIOLATION: Result cannot be Infinity and NaN!");

            assert_tiny_not_huge: assert (!(tiny_f && huge_f))
                else $error("SVA VIOLATION: Result cannot be Tiny and Huge!");

            assert_zero_not_huge: assert (!(zero_f && huge_f))
                else $error("SVA VIOLATION: Result cannot be Zero and Huge!");
                
            assert_inf_not_tiny:  assert (!(inf_f && tiny_f))
                else $error("SVA VIOLATION: Result cannot be Infinity and Tiny!");

            assert_nan_not_tiny: assert (!(nan_f && tiny_f))
                else $error("SVA VIOLATION: NaN cannot assert with Tiny!");
                
            assert_nan_not_huge: assert (!(nan_f && huge_f))
                else $error("SVA VIOLATION: NaN cannot assert with Huge!");
                
            assert_nan_not_inexact: assert (!(nan_f && inexact_f))
                else $error("SVA VIOLATION: NaN cannot assert with Inexact!");

            assert_unused_bit: assert (status[6] == 1'b0)
                else $error("SVA VIOLATION: Unused Bit 6 must be 0!");
                
            assert_div_by_zero_bit: assert (status[7] == 1'b0)
                else $error("SVA VIOLATION: Div by 0 Bit 7 must be 0 for an Adder!");
        end
    end
endmodule