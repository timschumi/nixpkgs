{
  stdenv,
  lib,
  pythonAtLeast,
  pythonOlder,
  buildPythonPackage,
  fetchFromGitHub,
  cargo,
  rustPlatform,
  rustc,
  libiconv,
  # Python requirements
  dill,
  numpy,
  networkx,
  ply,
  psutil,
  python-constraint,
  python-dateutil,
  rustworkx,
  scipy,
  scikit-quant ? null,
  setuptools-rust,
  stevedore,
  symengine,
  sympy,
  tweedledum,
  withVisualization ? false,
  # Python visualization requirements, optional
  ipywidgets,
  matplotlib,
  pillow,
  pydot,
  pygments,
  pylatexenc,
  seaborn,
  # Crosstalk-adaptive layout pass
  withCrosstalkPass ? false,
  z3-solver,
  # test requirements
  ddt,
  hypothesis,
  nbformat,
  nbconvert,
  pytestCheckHook,
  python,
}:

let
  visualizationPackages = [
    ipywidgets
    matplotlib
    pillow
    pydot
    pygments
    pylatexenc
    seaborn
  ];
  crosstalkPackages = [ z3-solver ];
in

buildPythonPackage rec {
  pname = "qiskit-terra";
  version = "0.25.1";
  format = "setuptools";

  disabled = pythonOlder "3.7" || pythonAtLeast "3.11";

  src = fetchFromGitHub {
    owner = "qiskit";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-4/LVKDNxKsRztCtU/mMfKMVHHJqfadZXmxeOlnlz9Tc=";
  };

  nativeBuildInputs = [
    setuptools-rust
    rustc
    cargo
    rustPlatform.cargoSetupHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = "sha256-nTYrNH3h1kAwwPx7OMw6eI61vYy8iFhm4eWDTGhWxt4=";
  };

  propagatedBuildInputs = [
    dill
    numpy
    networkx
    ply
    psutil
    python-constraint
    python-dateutil
    rustworkx
    scipy
    scikit-quant
    stevedore
    symengine
    sympy
    tweedledum
  ]
  ++ lib.optionals withVisualization visualizationPackages
  ++ lib.optionals withCrosstalkPass crosstalkPackages;

  # *** Tests ***
  nativeCheckInputs = [
    pytestCheckHook
    ddt
    hypothesis
    nbformat
    nbconvert
  ]
  ++ lib.optionals (!withVisualization) visualizationPackages;

  pythonImportsCheck = [
    "qiskit"
    "qiskit.pulse"
  ];

  disabledTestPaths = [
    "test/randomized/test_transpiler_equivalence.py" # collection requires qiskit-aer, which would cause circular dependency
    # These tests are nondeterministic and can randomly fail.
    # We ignore them here for deterministic building.
    "test/randomized/"
    # These tests consistently fail on GitHub Actions build
    "test/python/quantum_info/operators/test_random.py"
    # Too many floating point arithmetic errors
    "test/visual/mpl/circuit/test_circuit_matplotlib_drawer.py"
  ];
  pytestFlags = [ "--durations=10" ];
  disabledTests = [
    "TestUnitarySynthesisPlugin" # use unittest mocks for transpiler.run(), seems incompatible somehow w/ pytest infrastructure
    # matplotlib tests seems to fail non-deterministically
    "TestMatplotlibDrawer"
    "TestGraphMatplotlibDrawer"
    "test_copy" # assertNotIn doesn't seem to work as expected w/ pytest vs unittest

    "test_bound_pass_manager" # AssertionError: 0 != 2
    "test_complex_parameter_bound_to_real" # qiskit.circuit.exceptions.CircuitError: "Invalid param type <class 'complex'> for gate rx."
    "test_expressions_of_parameter_with_constant" # Floating point arithmetic error
    "test_handle_measurement" # AssertionError: The two circuits are not equal

    # Flaky tests
    "test_pulse_limits" # Fails on GitHub Actions, probably due to minor floating point arithmetic error.
    "test_cx_equivalence" # Fails due to flaky test
    "test_two_qubit_synthesis_not_pulse_optimal" # test of random circuit, seems to randomly fail depending on seed
    "test_qv_natural" # fails due to sign error. Not sure why
  ]
  ++ lib.optionals (lib.versionAtLeast matplotlib.version "3.4.0") [ "test_plot_circuit_layout" ]
  # Disabling slow tests for build constraints
  ++ [
    "test_all_examples"
    "test_controlled_random_unitary"
    "test_controlled_standard_gates_1"
    "test_jupyter_jobs_pbars"
    "test_lookahead_swap_higher_depth_width_is_better"
    "test_move_measurements"
    "test_job_monitor"
    "test_wait_for_final_state"
    "test_multi_controlled_y_rotation_matrix_basic_mode"
    "test_two_qubit_weyl_decomposition_abc"
    "test_isometry"
    "test_parallel"
    "test_random_state"
    "test_random_clifford_valid"
    "test_to_matrix"
    "test_block_collection_reduces_1q_gate"
    "test_multi_controlled_rotation_gate_matrices"
    "test_block_collection_runs_for_non_cx_bases"
    "test_with_two_qubit_reduction"
    "test_basic_aer_qasm"
    "test_hhl"
    "test_H2_hamiltonian"
    "test_max_evals_grouped_2"
    "test_qaoa_qc_mixer_4"
    "test_abelian_grouper_random_2"
    "test_pauli_two_design"
    "test_shor_factoring"
    "test_sample_counts_memory_ghz"
    "test_two_qubit_weyl_decomposition_ab0"
    "test_sample_counts_memory_superposition"
    "test_piecewise_polynomial_function"
    "test_piecewise_chebyshev_mutability"
    "test_bit_conditional_no_cregbundle"
    "test_gradient_wrapper2"
    "test_two_qubit_weyl_decomposition_abmb"
    "test_two_qubit_weyl_decomposition_abb"
    "test_vqe_qasm"
    "test_dag_from_networkx"
    "test_defaults_to_dict_46"
  ];

  # Moves tests to $PACKAGEDIR/test. They can't be run from /build because of finding
  # cythonized modules and expecting to find some resource files in the test directory.
  preCheck = ''
    export PACKAGEDIR=$out/${python.sitePackages}
    echo "Moving Qiskit test files to package directory"
    cp -r $TMP/$sourceRoot/test $PACKAGEDIR
    cp -r $TMP/$sourceRoot/examples $PACKAGEDIR

    # run pytest from Nix's $out path
    pushd $PACKAGEDIR
  '';
  postCheck = ''
    rm -r test
    rm -r examples
    popd
  '';

  meta = with lib; {
    description = "Provides the foundations for Qiskit";
    longDescription = ''
      Allows the user to write quantum circuits easily, and takes care of the constraints of real hardware.
    '';
    homepage = "https://qiskit.org/terra";
    downloadPage = "https://github.com/QISKit/qiskit-terra/releases";
    changelog = "https://qiskit.org/documentation/release_notes.html";
    license = licenses.asl20;
    maintainers = with maintainers; [ drewrisinger ];
  };
}
