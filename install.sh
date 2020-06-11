#!/usr/bin/env bash
echo "Installing deploy_test v$(cat ./VERSION)..."
make install

echo ""
echo "Running initial tests to generate results/deploy_test.out"
make installcheck

# FIXME: add safety if !file
cp results/deploy_test.out expected/deploy_test.out

make installcheck
