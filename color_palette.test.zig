const std = @import("std");
const testing = std.testing;
const color_palette = @import("color_palette_contract.zig");

const MAX_U64: u64 = 18446744073709551615;
var test_panic_expected = false;

fn panic(msg: []const u8) noreturn {
    if (test_panic_expected) {
        test_panic_expected = false;
        std.process.exit(0);
    }
    std.debug.print("Test panic: {s}\n", .{msg});
    std.process.exit(1);
}

const TestContext = struct {
    storage: std.StringHashMap([]const u8),
    registers: std.AutoHashMap(u64, []const u8),
    input: []u8,
    register: []u8,
    return_value: []u8,
    signer: []u8,
    current_account: []u8,

    pub fn init() !TestContext {
        return TestContext{
            .storage = std.StringHashMap([]const u8).init(testing.allocator),
            .registers = std.AutoHashMap(u64, []const u8).init(testing.allocator),
            .input = try testing.allocator.dupe(u8, ""),
            .register = try testing.allocator.dupe(u8, ""),
            .return_value = try testing.allocator.dupe(u8, ""),
            .signer = try testing.allocator.dupe(u8, "test.near"),
            .current_account = try testing.allocator.dupe(u8, "test.near"),
        };
    }

    pub fn deinit(self: *TestContext) void {
        self.storage.deinit();
        self.registers.deinit();
        testing.allocator.free(self.input);
        testing.allocator.free(self.register);
        testing.allocator.free(self.return_value);
        testing.allocator.free(self.signer);
        testing.allocator.free(self.current_account);
    }

    pub fn setInput(self: *TestContext, new_input: []const u8) !void {
        testing.allocator.free(self.input);
        self.input = try testing.allocator.dupe(u8, new_input);
    }

    pub fn setSigner(self: *TestContext, new_signer: []const u8) !void {
        testing.allocator.free(self.signer);
        self.signer = try testing.allocator.dupe(u8, new_signer);
    }
};

// Mock state for tests
var ctx: TestContext = undefined;

// Mock NEAR runtime functions
export fn input(register_id: u64) void {
    ctx.registers.put(register_id, ctx.input) catch {
        panic("Failed to store in register");
    };
}

export fn signer_account_id(register_id: u64) void {
    ctx.registers.put(register_id, ctx.signer) catch {
        panic("Failed to store signer in register");
    };
}

export fn current_account_id(register_id: u64) void {
    ctx.registers.put(register_id, ctx.current_account) catch {
        panic("Failed to store current account in register");
    };
}

export fn read_register(register_id: u64, ptr: u64) void {
    if (ctx.registers.get(register_id)) |data| {
        const dest = @as([*]u8, @ptrFromInt(ptr));
        @memcpy(dest[0..data.len], data);
    }
}

export fn register_len(register_id: u64) u64 {
    if (ctx.registers.get(register_id)) |data| {
        return data.len;
    }
    return 0;
}

export fn value_return(len: u64, ptr: u64) void {
    const slice = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    testing.allocator.free(ctx.return_value);
    ctx.return_value = testing.allocator.dupe(u8, slice) catch {
        panic("Failed to duplicate return value");
        unreachable;
    };
}

export fn storage_has_key(key_len: u64, key_ptr: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    return if (ctx.storage.contains(key)) 1 else 0;
}

export fn storage_read(key_len: u64, key_ptr: u64, register_id: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    if (ctx.storage.get(key)) |value| {
        ctx.registers.put(register_id, value) catch {
            panic("Failed to store value in register");
        };
        return 1;
    }
    return 0;
}

export fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, register_id: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    const value = @as([*]const u8, @ptrFromInt(value_ptr))[0..value_len];
    const value_copy = testing.allocator.dupe(u8, value) catch {
        panic("Failed to duplicate value");
        unreachable;
    };
    if (ctx.storage.get(key)) |old_value| {
        testing.allocator.free(old_value);
    }
    ctx.storage.put(key, value_copy) catch panic("Failed to store value");
    _ = register_id;
    return 1;
}

export fn log_utf8(len: u64, ptr: u64) void {
    const str = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    std.debug.print("{s}\n", .{str});
}

export fn panic_utf8(len: u64, ptr: u64) void {
    const str = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    panic(str);
}

test "initialization" {
    ctx = try TestContext.init();
    defer ctx.deinit();

    // Test initial initialization
    color_palette.init();
    try testing.expect(ctx.storage.contains("owner"));
    try testing.expectEqualStrings("test.near", ctx.storage.get("owner").?);

    // Test double initialization should panic
    test_panic_expected = true;
    color_palette.init();
    try testing.expect(!test_panic_expected);
}

test "add palette" {
    ctx = try TestContext.init();
    defer ctx.deinit();

    // Initialize contract
    color_palette.init();

    // Test adding valid palette
    const valid_input = "{\"name\":\"Test Palette\",\"colors\":[\"#FF0000\",\"#00FF00\",\"#0000FF\"]}";
    try ctx.setInput(valid_input);
    color_palette.add_palette();

    // Verify palette was added
    try testing.expect(ctx.storage.contains("palette:palette-1"));

    // Test invalid color format
    const invalid_color = "{\"name\":\"Invalid\",\"colors\":[\"#GG0000\"]}";
    try ctx.setInput(invalid_color);
    test_panic_expected = true;
    color_palette.add_palette();
    try testing.expect(!test_panic_expected);
}

test "remove palette" {
    ctx = try TestContext.init();
    defer ctx.deinit();

    // Initialize contract
    color_palette.init();

    // Add a palette first
    const palette_input = "{\"name\":\"Test Palette\",\"colors\":[\"#FF0000\"]}";
    try ctx.setInput(palette_input);
    color_palette.add_palette();

    // Test removing as non-owner
    try ctx.setSigner("other.near");
    const remove_input = "{\"id\":\"palette-1\"}";
    try ctx.setInput(remove_input);
    test_panic_expected = true;
    color_palette.remove_palette();
    try testing.expect(!test_panic_expected);

    // Test removing as owner
    try ctx.setSigner("test.near");
    try ctx.setInput(remove_input);
    color_palette.remove_palette();
    try testing.expect(!ctx.storage.contains("palette:palette-1"));
}

test "get palettes" {
    ctx = try TestContext.init();
    defer ctx.deinit();

    // Initialize contract
    color_palette.init();

    // Add some palettes
    const palette1 = "{\"name\":\"Palette 1\",\"colors\":[\"#FF0000\"]}";
    try ctx.setInput(palette1);
    color_palette.add_palette();

    const palette2 = "{\"name\":\"Palette 2\",\"colors\":[\"#00FF00\"]}";
    try ctx.setInput(palette2);
    color_palette.add_palette();

    // Test get_palettes
    color_palette.get_palettes();
    try testing.expect(ctx.return_value.len > 0);
}
