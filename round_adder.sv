import round_pkg::*;

// ============================================================================
// Module: round_adder
// Description: Applies IEEE-754 rounding rules to the normalized 27-bit mantissa.
//              Outputs a 25-bit mantissa to catch potential overflow from rounding.
// ============================================================================

module round_adder (
    input  round_mode_t round,
    input  logic [26:0] norm_mant,
    input  logic        z_sign,
    output logic [24:0] round_mant,
    output logic        inexact_bit
);
    logic G,R,S;
    logic [23:0] base_mant;

    assign G = norm_mant[2];
    assign R = norm_mant[1];
    assign S = norm_mant[0];

    assign inexact_bit = G|R|S;
    assign base_mant   = norm_mant[26:3];

    always_comb begin
        // Default assignment
        round_mant = 25'(base_mant);

        case(round)
            IEEE_near: begin///////////////////////////NOT SURE NEEDS EXTRA CHECK
                if(G==1'b1)begin
                    if(R == 1'b1 || S == 1'b1) begin
                        round_mant = 25'(base_mant) + 25'b1;
                    end
                    else if (base_mant[0] == 1'b1) begin
                        round_mant = 25'(base_mant) + 25'b1;
                    end
                end
            end
            IEEE_zero: begin
                // default assignment already handles this
            end
            IEEE_ninf: begin
                if(z_sign == 1'b1 && (G|R|S) == 1'b1)
                    round_mant = 25'(base_mant) + 25'b1;
            end
            IEEE_pinf: begin
                if(z_sign == 1'b0 && (G|R|S) == 1'b1)
                    round_mant = 25'(base_mant) + 25'b1;
            end
            IEEE_near_maxMag: begin
                if(G == 1'b1)
                    round_mant = 25'(base_mant) + 25'b1; 
            end
        endcase
    end   
endmodule