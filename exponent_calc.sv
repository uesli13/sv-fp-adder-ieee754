module exponent_calc(
    input logic [7:0] Ea, Eb,
    output logic [7:0] max_exp,
    output logic [8:0] exp_diff,
    output logic sign_exp_diff
);

always_comb begin
    //If exponent of a is greater or equal than the exponent of b
    if(Ea >= Eb) begin
        max_exp = Ea;
        exp_diff = Ea - Eb;
        sign_exp_diff = 1'b1;
    end
    //If exponent of b is greater than the exponent of a
    else     begin
        max_exp = Eb;
        exp_diff = Eb - Ea;
        sign_exp_diff = 1'b0;
    end
end
endmodule