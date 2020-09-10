#!/usr/bin/env bash
echo "Installing pgdeploy v$(cat ./VERSION)..."
make install

echo ""
echo "Running initial tests to generate results/pgdeploy.out"
make installcheck

# FIXME: add safety if !file
cp results/pgdeploy.out expected/pgdeploy.out

make installcheck
