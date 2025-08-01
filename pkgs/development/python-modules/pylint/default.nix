{
  lib,
  stdenv,
  astroid,
  buildPythonPackage,
  dill,
  fetchFromGitHub,
  gitpython,
  isort,
  mccabe,
  platformdirs,
  py,
  pytest-timeout,
  pytest-xdist,
  pytest7CheckHook,
  pythonOlder,
  requests,
  setuptools,
  tomli,
  tomlkit,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "pylint";
  version = "3.3.7";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "pylint-dev";
    repo = "pylint";
    tag = "v${version}";
    hash = "sha256-EMLnwFurIhTdUJqy9/DLTuucDhlmA5fCPZZ6TA87nEU=";
  };

  build-system = [ setuptools ];

  dependencies = [
    astroid
    dill
    isort
    mccabe
    platformdirs
    tomlkit
  ]
  ++ lib.optionals (pythonOlder "3.11") [ tomli ]
  ++ lib.optionals (pythonOlder "3.10") [ typing-extensions ];

  nativeCheckInputs = [
    gitpython
    # https://github.com/PyCQA/pylint/blob/main/requirements_test_min.txt
    py
    pytest-timeout
    pytest-xdist
    pytest7CheckHook
    requests
    typing-extensions
  ];

  pytestFlags = [
    # DeprecationWarning: pyreverse will drop support for resolving and
    # displaying implemented interfaces in pylint 3.0. The
    # implementation relies on the '__implements__'  attribute proposed
    # in PEP 245, which was rejected in 2006.
    "-Wignore::DeprecationWarning"
    "-v"
  ];

  preCheck = ''
    export HOME=$TEMPDIR
  '';

  disabledTestPaths = [
    "tests/benchmark"
    # tests miss multiple input files
    # FileNotFoundError: [Errno 2] No such file or directory
    "tests/pyreverse/test_writer.py"
  ];

  disabledTests = [
    # AssertionError when self executing and checking output
    # expected output looks like it should match though
    "test_invocation_of_pylint_config"
    "test_generate_rcfile"
    "test_generate_toml_config"
    "test_help_msg"
    "test_output_of_callback_options"
    # Failed: DID NOT WARN. No warnings of type (<class 'UserWarning'>,) were emitted. The list of emitted warnings is: [].
    "test_save_and_load_not_a_linter_stats"
    # Truncated string expectation mismatch
    "test_truncated_compare"
    # Probably related to pytest versions, see pylint-dev/pylint#9477 and pylint-dev/pylint#9483
    "test_functional"
    # AssertionError: assert [('specializa..., 'Ancestor')] == [('aggregatio..., 'Ancestor')]
    "test_functional_relation_extraction"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "test_parallel_execution"
    "test_py3k_jobs_option"
  ];

  meta = {
    description = "Bug and style checker for Python";
    homepage = "https://pylint.readthedocs.io/en/stable/";
    changelog = "https://github.com/pylint-dev/pylint/releases/tag/v${version}";
    longDescription = ''
      Pylint is a Python static code analysis tool which looks for programming errors,
      helps enforcing a coding standard, sniffs for code smells and offers simple
      refactoring suggestions.
      Pylint is shipped with following additional commands:
      - pyreverse: an UML diagram generator
      - symilar: an independent similarities checker
      - epylint: Emacs and Flymake compatible Pylint
    '';
    license = lib.licenses.gpl2Plus;
    maintainers = [ ];
    mainProgram = "pylint";
  };
}
