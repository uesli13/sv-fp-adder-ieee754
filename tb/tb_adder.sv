// ============================================================================
// Module:      tb_adder
// Description: Testbench for the floating-point adder. 
//              It generates random and corner-case inputs, applies them to the DUT,
//              and compares the DUT's output against a reference model (Hardfloat).
//              The testbench also includes SVA assertions to check for status bit correctness.
// ============================================================================

`timescale 1ns/1ps

module tb_adder ();
    logic [31:0] result;        // result = a + b
    logic [7:0]  status;        // Status bits for the result
    logic [31:0] a, b;
    logic [2:0]  round;         // Rounding mode
    bit          clk, resetn;   // Clock and reset signals

    // =========================================================================
    // Instantiation of the DUT 
    // =========================================================================

    fp_adder_top dut (
        .a(a),
        .b(b),
        .round(round),
        .clk(clk),
        .resetn(resetn),
        .result(result),
        .status(status)
    );

    // =========================================================================
    // SVA Binding
    // =========================================================================

    // Bind the immediate assertions
    bind dut test_status_bits assert_bits_inst (
        .resetn(resetn),
        .status(status)
    );

    // Bind the concurrent assertions
    bind dut test_status_z_combinations assert_combos_inst (
        .clk(clk),
        .status(status),
        .result(result),
        .a(a),
        .b(b)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    always #5 clk = ~clk;

    // =========================================================================
	// Instantiattion and proper wiring of the hardfloat reference model
    // =========================================================================
	logic [31:0] results_hf;	// The results_hf 32-bit floatinf point number (after the recoding in Hardfloat), will be translated to the results_ref
	logic [31:0] results_ref;	// This is the golden reference value to be compared with the DUT result
	logic [2:0]  rnd_hf;
	logic [31:0] a_hf, b_hf;	// These will be the floating point 32-bit inputs to the Hardfloat rec modules

    logic [32:0] recFN_a, recFN_b, recFN_result; // Intermediate 33-bit wires for the recoded format
    logic [4:0]  exceptionFlags_hf;               // Exception flags from Hardfloat

    assign rnd_hf = round;

    // Convert a_hf to recoded format
    fNToRecFN #(8, 24) a_conv (
        .in(a_hf),
        .out(recFN_a)
    );

    // Convert b_hf to recoded format
    fNToRecFN #(8, 24) b_conv (
        .in(b_hf),
        .out(recFN_b)
    );

    // Hardfloat addition module instantiation
    addRecFN #(8, 24) adder_hf (
        .control(1'b0),          // control=0 is addition
        .subOp(1'b0),            // subOp=0 means we are adding a+b (sign bits handle negatives)
        .a(recFN_a),
        .b(recFN_b),
        .roundingMode(rnd_hf),
        .out(recFN_result),
        .exceptionFlags(exceptionFlags_hf)
    );

    // Convert recoded result back to standard IEEE-754 format
    recFNToFN #(8, 24) res_conv (
        .in(recFN_result),
        .out(results_hf)
    );

    // =========================================================================
    // Update the reference model inputs and output to match our IEEE compliance 
    // =========================================================================

	always_comb begin
		// If a is NaN => Inf
		if(a[30:23] == '1) begin
			a_hf = {a[31], {8{1'b1}}, {23{1'b0}}};
		end
		// If a is denorm => Zero
		else if(a[30:23] == '0 ) begin
			a_hf = {a[31], {31{1'b0}}};
		end
		else begin
			a_hf = a;
		end

		// If b is NaN => Inf
		if(b[30:23] == '1) begin
			b_hf = {b[31], {8{1'b1}}, {23{1'b0}}};
		end
		// If b is denorm => Zero
		 else if(b[30:23] == '0 ) begin
			b_hf = {b[31], {31{1'b0}}};
		end
		else begin
			b_hf = b;
		end

		// If result is denorm => Zero or Min normal
		if(results_hf[30:23] == '0 && |results_hf[22:0]) begin
			if (round == 3'b001 || round == 3'b000 || (round == 3'b010 && !results_hf[31]) || (round == 3'b011 && results_hf[31]) || round == 3'b100)
				results_ref = {results_hf[31], {31{1'b0}}};
			else
				results_ref = {results_hf[31], {7{1'b0}}, 1'b1, {23{1'b0}}};
		end
		// If result is NaN => Inf
		else if(results_hf[30:23] == '1 && |results_hf[22:0]) begin
			results_ref = {results_hf[31], {8{1'b1}}, {23{1'b0}}};
		end
		else
			results_ref = results_hf;
	end

    // =========================================================================
    // Verification Variables
    // =========================================================================

    int total_random_tests = 0;
    int success_random_tests = 0;
    int total_corner_tests = 0;
    int success_corner_tests = 0;

    // Enum to track which type of test is currently flowing through the pipeline
    typedef enum bit [1:0] {
        NONE,
        RANDOM,
        CORNER
    } test_type_e;

    test_type_e current_test_type = NONE;

    // =========================================================================
    // Alignment Pipeline (Shift Registers) to delay the reference model's output to match the DUT's 2-cycle latency
    // =========================================================================
    
    logic [31:0] ref_d1, ref_d2;
    logic [31:0] a_d1, a_d2; 
    logic [31:0] b_d1, b_d2;
    logic [2:0]  round_d1, round_d2;
    test_type_e  type_d1, type_d2;
    logic        valid_d1, valid_d2;

    // Shift data through the pipeline at every positive edge
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_d1 <= 0;
            valid_d2 <= 0;
        end else begin
            // Stage 1 delay
            ref_d1 <= results_ref;   
            a_d1 <= a;
            b_d1 <= b;
            round_d1 <= round;
            type_d1 <= current_test_type;
            valid_d1 <= 1'b1;        
            
            // Stage 2 delay
            ref_d2 <= ref_d1;
            a_d2 <= a_d1;
            b_d2 <= b_d1;
            round_d2 <= round_d1;
            type_d2 <= type_d1;
            valid_d2 <= valid_d1;
        end
    end

    // =========================================================================
    // Self-Checking Monitor
    // =========================================================================

    // Check results on the negative edge, right after the DUT has updated its outputs
    always @(negedge clk) begin
        if (valid_d2 && type_d2 != NONE) begin
            if (result !== ref_d2) begin
                // Display only errors
                $display("ERROR at %0t | Test: %s | A=%h, B=%h, Round=%h | Expected=%h, Got=%h", 
                         $time, type_d2.name(), a_d2, b_d2, round_d2, ref_d2, result);
            end else begin
                // If they match, increment our success counters
                if (type_d2 == RANDOM) success_random_tests++;
                if (type_d2 == CORNER) success_corner_tests++;
            end
        end
    end

    // =========================================================================
    // Stimulus Tasks
    // =========================================================================

    // Task that generates random tests
    task run_random_tests(int num_tests);
        current_test_type = RANDOM;
        
        for (int i = 0; i < num_tests; i++) begin
            @(negedge clk); // Change inputs on negative edge
            
            // Generate random 32-bit inputs
            a = $urandom();
            b = $urandom();
            
            round = $urandom_range(0, 4); 
            
            total_random_tests++;
        end
    endtask

    //  Enum for the 10 specific corner cases
    typedef enum bit [3:0] {
        NEG_NAN, POS_NAN, 
        NEG_INF, POS_INF, 
        NEG_NORM, POS_NORM, 
        NEG_DENORM, POS_DENORM, 
        NEG_ZERO, POS_ZERO
    } corner_t;

    // Function to generate a 32-bit IEEE-754 value based on the requested corner case
    function logic [31:0] generate_corner_val(corner_t c);
        logic [22:0] rand_frac;
        logic [7:0] rand_exp;
        
        // Generate random fraction (ensure it's not strictly zero by OR-ing with 1)
        rand_frac = $urandom() | 23'h000001; 
        
        // Generate random normal exponent (1 to 254)
        rand_exp = $urandom_range(1, 254);   

        case (c)
            NEG_NAN:    return {1'b1, 8'hFF, rand_frac};
            POS_NAN:    return {1'b0, 8'hFF, rand_frac};
            NEG_INF:    return 32'hFF800000;
            POS_INF:    return 32'h7F800000;
            NEG_NORM:   return {1'b1, rand_exp, $urandom()}; // Frac can be anything here
            POS_NORM:   return {1'b0, rand_exp, $urandom()};
            NEG_DENORM: return {1'b1, 8'h00, rand_frac};
            POS_DENORM: return {1'b0, 8'h00, rand_frac};
            NEG_ZERO:   return 32'h80000000;
            POS_ZERO:   return 32'h00000000;
            default:    return 32'h00000000;
        endcase
    endfunction

    // Task that generates corner-case tests
    task run_corner_tests();
        current_test_type = CORNER;
        
        // Loop through all 10 corner types for input 'A'
        for (int i = 0; i < 10; i++) begin
            
            // Loop through all 10 corner types for input 'B'
            for (int j = 0; j < 10; j++) begin
                
                // Test each combination against all 5 rounding modes
                for (int r = 0; r < 5; r++) begin
                    @(negedge clk); // Change inputs on negative edge
                    
                    // Cast integer iterators back to our enum type
                    a = generate_corner_val(corner_t'(i));
                    b = generate_corner_val(corner_t'(j));
                    round = r;
                    
                    total_corner_tests++;
                end
            end
        end
    endtask


    // =========================================================================
    // Main Execution
    // =========================================================================

    initial begin
        // Initialize variables
        clk    = 0;
        resetn = 0;
        a      = 0;
        b      = 0;
        round  = 0;
        
        // Hold reset for a few cycles, then release
        #15; 
        resetn = 1;
        
        // Run 1000 Random Tests
        $display("Starting Random Tests...");
        run_random_tests(1000);
        
        // Run Corner tests
        $display("Starting Corner Tests...");
        run_corner_tests();

        // Wait 5 cycles for the final tests to flush through the 2-cycle pipeline
        current_test_type = NONE;
        repeat(5) @(posedge clk); 
        
        // Print the Final Statistics
        $display("=================================================");
        $display("              SIMULATION STATISTICS              ");
        $display("=================================================");
        $display("Total Tests Executed: %0d", (total_random_tests + total_corner_tests));
        $display("Random Tests: %0d / %0d SUCCESSFUL", success_random_tests, total_random_tests);
        $display("Corner Tests: %0d / %0d SUCCESSFUL", success_corner_tests, total_corner_tests);
        $display("=================================================");
        
        $stop;
    end

endmodule