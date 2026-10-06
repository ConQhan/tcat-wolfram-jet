% run_all_tests.m - full test suite, entry point for matlab -batch.
%   Usage: matlab -batch "run('<tool folder>/tests/run_all_tests.m')"

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(root));

suite = testsuite(here);
results = run(suite);
disp(table(results));

nfail = nnz(~[results.Passed]);
if nfail > 0
    error('tcat:tests:failed', '%d/%d tests failed.', nfail, numel(results));
else
    fprintf('\nALL TESTS PASSED: %d/%d\n', numel(results), numel(results));
end
