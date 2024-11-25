#!/usr/bin/bash

if [[ `pgrep "Runner."` ]]; then
    echo "github runner: active [pid: `pgrep Runner.`]"
else
    echo "github runner: not active."
fi

echo "npm: `npm --version`"
echo "pnpm: `pnpm --version`"
echo "node: `node --version`"
echo "rust: `rustc --version`"
echo "      `cargo --version`"
echo ""
echo `go version`
echo `python --version`
echo `php --version | sed -n 1p`
echo `R --version | sed -n 1p`
