% run_gui.m - opens the GCAM turbojet design tool (GcamDesignApp).
%   Usage: run this file in MATLAB (Run button or F5).

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(root));

GcamDesignApp;
