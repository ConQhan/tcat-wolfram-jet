% run_gui.m - opens TCAT, the Turbojet Cycle Analysis Tool (TcatDesignApp).
%   Usage: run this file in MATLAB (Run button or F5).

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(root));

TcatDesignApp;
