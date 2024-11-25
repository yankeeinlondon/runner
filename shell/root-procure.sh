# install Node environment 
nala install nodejs npm n -y
npm i -g pnpm
pnpm setup
pnpm i -g n typescript dd eslint tsx

# install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh