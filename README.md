# SLEET Color Palette Contract
a small near smart contract for color palttes written in zig

---


### Building the Contract

1. Install [Zig](https://ziglang.org/learn/getting-started/#installing-zig) (v0.13.0 recommended)

2. Build the contract:
```bash
# Build directly
zig build-exe color_palette_contract.zig -target wasm32-freestanding -O ReleaseSmall --export=init --export=add_palette --export=remove_palette --export=get_palettes --export=get_palette_by_id --export=like_palette --export=unlike_palette --export=get_likes -fno-entry

# Build and run tests
zig build --release=small
zig build test
zig test color_palette.test.zig
```

This will create `color_palette_contract.wasm` file.

---

## Contract Methods

- `init()`: Initializes the contract and sets the owner
- `add_palette(name: string, colors: string[])`: Adds a new color palette
- `remove_palette(id: string)`: Removes a palette (owner only)
- `get_palettes()`: Returns all palettes
- `get_palette_by_id(id: string)`: Returns a specific palette
- `like_palette(palette_id: string)`: Adds a like to a palette
- `unlike_palette(palette_id: string)`: Removes a like from a palette
- `get_likes(palette_id: string)`: Gets the total likes for a palette

---


## Example Usage

### Deploying

```bash
# Deploy contract
near deploy --wasmFile color_palette_contract.wasm mycontract.myaccount.testnet

# Initialize contract
near call mycontract.myaccount.testnet init --accountId myaccount.testnet
```

### Basic Operations
```bash
# Initialize contract
near call NEW_CONTRACT_ACCOUNT_ID init --accountId OWNER_ID

# Add a new palette
near call NEW_CONTRACT_ACCOUNT_ID add_palette '{"name":"Ocean Breeze","colors":["#1B98E0","#247BA0","#006494"]}' --accountId YOUR_ACCOUNT_ID

# View all palettes
near view NEW_CONTRACT_ACCOUNT_ID get_palettes

# Get a specific palette
near view NEW_CONTRACT_ACCOUNT_ID get_palette_by_id '{"id":"palette-1"}'


# Like a palette
near call NEW_CONTRACT_ACCOUNT_ID like_palette '{"palette_id":"palette-1"}' --accountId YOUR_ACCOUNT_ID

# Unlike a palette
near call NEW_CONTRACT_ACCOUNT_ID unlike_palette '{"palette_id":"palette-1"}' --accountId YOUR_ACCOUNT_ID

# Check total likes for a palette
near view NEW_CONTRACT_ACCOUNT_ID get_likes '{"palette_id":"palette-1"}'
```


#### TO DO
- add tests
- add method to get palette count
- add ways to query palette info

---

copyright 2025 by sleet.near