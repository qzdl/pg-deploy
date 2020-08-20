#!/usr/bin/env bash
echo "Installing pg_deploy v$(cat ./VERSION)..."
make install

echo ""
echo "Running initial tests to generate results/pg_deploy.out"
make installcheck

# FIXME: add safety if !file
cp results/pg_deploy.out expected/pg_deploy.out

make installcheck
