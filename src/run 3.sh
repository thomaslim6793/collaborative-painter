#!/bin/sh

export MACOSX_DEPLOYMENT_TARGET=11
dub run

# How to use: 
# 1) Make the script executable by running following on terminal: chmod +x run.sh
# 2) Then run the above script with: ./run.sh