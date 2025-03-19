# Color Palette Contract V2

## New Features in V2
- Like/Heart functionality for palettes
- Total like counts for each palette
- Improved storage management
- Backwards compatibility with V1

## Building the Contract

1. Install [Zig](https://ziglang.org/learn/getting-started/#installing-zig) (v0.13.0 recommended)

2. Build the contract:
```bash
zig build-exe color_palette_contract.zig -target wasm32-freestanding -O ReleaseSmall --export=init --export=add_palette --export=remove_palette --export=get_palettes --export=get_palette_by_id --export=like_palette --export=unlike_palette --export=get_likes -fno-entry
```

This will create `color_palette_contract.wasm` file.

## Contract Methods

### V1 Methods (Maintained for Compatibility)
- `init()`: Initializes the contract and sets the owner
- `add_palette(name: string, colors: string[])`: Adds a new color palette
- `remove_palette(id: string)`: Removes a palette (owner only)
- `get_palettes()`: Returns all palettes
- `get_palette_by_id(id: string)`: Returns a specific palette

### New V2 Methods
- `like_palette(palette_id: string)`: Adds a like to a palette
- `unlike_palette(palette_id: string)`: Removes a like from a palette
- `get_likes(palette_id: string)`: Gets the total likes for a palette

## Example Usage

### Basic Operations (V1 Compatible)
```bash
# Initialize contract
near call NEW_CONTRACT_ACCOUNT_ID init --accountId OWNER_ID

# Add a new palette
near call NEW_CONTRACT_ACCOUNT_ID add_palette '{"name":"Ocean Breeze","colors":["#1B98E0","#247BA0","#006494"]}' --accountId YOUR_ACCOUNT_ID

# View all palettes
near view NEW_CONTRACT_ACCOUNT_ID get_palettes

# Get a specific palette
near view NEW_CONTRACT_ACCOUNT_ID get_palette_by_id '{"id":"palette-1"}'
```

### New Social Features (V2)
```bash
# Like a palette
near call NEW_CONTRACT_ACCOUNT_ID like_palette '{"palette_id":"palette-1"}' --accountId YOUR_ACCOUNT_ID

# Unlike a palette
near call NEW_CONTRACT_ACCOUNT_ID unlike_palette '{"palette_id":"palette-1"}' --accountId YOUR_ACCOUNT_ID

# Check total likes for a palette
near view NEW_CONTRACT_ACCOUNT_ID get_likes '{"palette_id":"palette-1"}'
```

## Upgrading from V1

1. Deploy the new contract to a new account:
```bash
near deploy --wasmFile color_palette_v2.wasm NEW_CONTRACT_ACCOUNT_ID
```

2. Initialize the V2 contract:
```bash
near call NEW_CONTRACT_ACCOUNT_ID init --accountId OWNER_ID
```

3. Migrate data from V1 (optional):
- Export palettes from V1 using `get_palettes`
- Import palettes to V2 using `add_palette`

## Potential Future Features

1. Categories and Tags
- Add categories to palettes
- Search/filter by categories
- Tag system for better organization

2. Social Features
- Comments on palettes
- Share functionality
- Follow other creators

3. Enhanced Palette Management
- Palette versioning
- Color descriptions
- Color combinations suggestions

4. Analytics
- Usage statistics
- Popular color combinations
- Trending palettes

5. Integration Features
- API endpoints for external services
- Export in various formats (CSS, SCSS, etc.)
- Color accessibility scoring

## Best Practices for Contract Updates

1. Always maintain backwards compatibility
2. Use semantic versioning for contract versions
3. Provide migration tools when needed
4. Document all changes thoroughly
5. Test upgrades on testnet first
6. Consider storage migration strategies
7. Plan for future extensibility