// ============================================================================
// Module:      exception_adder
// Description: Final stage of the FPU. Handles special IEEE-754 cases and 
//              overrides the calculated result if an exception
//              (Overflow/Underflow) occurs.
// ============================================================================

import round_pkg::*;

module exception_adder(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  round_mode_t round,
    input  logic [31:0] z_calc,
    input  logic        overflow,
    input  logic        underflow,
    input  logic        inexact_bit,
    output logic [31:0] result,
    output logic        zero_f,
    output logic        inf_f,
    output logic        nan_f,
    output logic        tiny_f,
    output logic        huge_f,
    output logic        inexact_f
);
    // enumeration for interpreting the type of number
    typedef enum logic [2:0] {
        ZERO     = 3'b000,
        INF      = 3'b001,
        NORM     = 3'b010,
        MIN_NORM = 3'b011,
        MAX_NORM = 3'b100
    } interp_t;

    // Function to classify a 32-bit number
    function automatic interp_t num_interp(input logic [31:0] in);
        logic [7:0]  exp = in[30:23];

        if(exp == 8'b0) begin
            return ZERO;
        end
        else if(exp == {8{1'b1}}) begin
            return INF;
        end
        else begin
            return NORM;
        end
    endfunction

    // Function to generate standard payload values
    function logic [30:0] z_num(interp_t num_type);
        case(num_type)
            ZERO:     return 31'b0;
            INF :     return {{8{1'b1}}, 23'b0};
            MIN_NORM: return {8'b1, 23'b0};
            MAX_NORM: return {{7{1'b1}}, 1'b0, {23{1'b1}}};
            default:  return 31'b0;
        endcase
    endfunction

    // Internal wires for signs
    logic z_sign, a_sign, b_sign;
    assign z_sign = z_calc[31];
    assign a_sign = a[31];
    assign b_sign = b[31];

    always_comb begin

        // Default flags to 0
        zero_f    = 1'b0;
        inf_f     = 1'b0;
        nan_f     = 1'b0;
        tiny_f    = 1'b0;
        huge_f    = 1'b0;
        inexact_f = 1'b0;

        // Exception 1: Zero + Zero
        if(num_interp(a) == ZERO && num_interp(b) == ZERO) begin
            if(a_sign == b_sign) begin
                result = {a_sign, z_num(ZERO)};
            end
            else begin
                if(round ==  IEEE_ninf) begin
                    result = {1'b1, z_num(ZERO)};
                end
                else begin
                    result = {1'b0, z_num(ZERO)};
                end
            end
            zero_f = 1'b1;
        end
        // Exception 2a: Zero + Infinity
        else if(num_interp(a) == ZERO  && num_interp(b) == INF) begin
            result = {b_sign, z_num(INF)};
            inf_f  = 1'b1;
        end
        // Exception 2b: Infinity + Zero
        else if (num_interp(a) == INF   && num_interp(b) == ZERO) begin
            result = {a_sign, z_num(INF)};
            inf_f  = 1'b1;  
        end
        // Exception 3: Infinity +- Infinity
        else if ((num_interp(a) == INF && num_interp(b) == INF)) begin
            if(a_sign != b_sign) begin
                result = {1'b0, z_num(INF)};
                nan_f = 1'b1;
            end
            else begin
                result = {a_sign, z_num(INF)};
                inf_f = 1'b1;
            end
        end
        // Exception 4a: Normal + Infinity
        else if (num_interp(a) == NORM && num_interp(b) == INF ) begin
            result = {b_sign, z_num(INF)};
            inf_f = 1'b1;
        end
        // Exception 4b: Infinity + Normal
        else if (num_interp(a) == INF  && num_interp(b) == NORM) begin
            result = {a_sign, z_num(INF)};
            inf_f = 1'b1;
        end
        //Exception 5a: Normal + Zero
        else if(num_interp(a) == NORM && num_interp(b) == ZERO)begin
            result = a;
            if(result[30:0] == 31'b0) zero_f = 1'b1;
        end
        //Exception 5b: Zero + Normal
        else if(num_interp(a) == ZERO && num_interp(b) == NORM) begin
            result = b;
            if(result[30:0] == 31'b0) zero_f = 1'b1;
        end        // Normal Numbers
        else begin
            // Case Overflow
            if(overflow == 1'b1) begin
                huge_f = 1'b1;
                inexact_f = 1'b1;

                // Handle overflow according to the rounding mode
                if(round == IEEE_near) begin
                    result = {z_sign, z_num(INF)};
                    inf_f = 1'b1;
                end
                else if (round == IEEE_zero) begin
                    result = {z_sign, z_num(MAX_NORM)};
                end
                else if (round == IEEE_ninf) begin
                    if(z_sign == 1'b0) begin
                        result = {z_sign, z_num(MAX_NORM)};
                    end
                    else begin
                        result = {z_sign, z_num(INF)};
                        inf_f = 1'b1;
                    end
                end
                else if (round == IEEE_pinf) begin
                    if(z_sign == 1'b0) begin
                        result = {z_sign, z_num(INF)};
                        inf_f = 1'b1;
                    end
                    else begin
                        result = {z_sign, z_num(MAX_NORM)};
                    end
                end
                else if(round == IEEE_near_maxMag) begin
                    result = {z_sign, z_num(INF)};
                    inf_f = 1'b1;
                end
            end
            // Case Underflow
            else if (underflow == 1'b1) begin
                tiny_f = 1'b1;
                inexact_f = 1'b1;

                // Handle underflow according to the rounding mode
                if(round == IEEE_near) begin
                    result = {z_sign, z_num(ZERO)};
                    zero_f = 1'b1;
                end
                else if (round == IEEE_zero) begin
                    result = {z_sign, z_num(ZERO)};
                    zero_f = 1'b1;
                end

                else if (round == IEEE_ninf) begin
                    if(z_sign == 1'b0) begin
                        result = {z_sign, z_num(ZERO)};
                        zero_f = 1'b1;
                    end
                    else begin
                        result = {z_sign, z_num(MIN_NORM)};
                    end
                end
                else if (round == IEEE_pinf) begin
                    if(z_sign == 1'b0) begin
                        result = {z_sign, z_num(MIN_NORM)};
                    end
                    else begin
                        result = {z_sign, z_num(ZERO)};
                        zero_f = 1'b1;
                    end
                end
                else if (round == IEEE_near_maxMag) begin
                    result = {z_sign, z_num(ZERO)};
                    zero_f = 1'b1;
                end
            end
            // Completely normal result!
            else begin
                result = z_calc;
                inexact_f = inexact_bit;
                
                if(result[30:0] == 31'b0) begin
                    zero_f = 1'b1;
                end

            end
        end
    end
endmodule