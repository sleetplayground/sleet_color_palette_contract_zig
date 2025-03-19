const std = @import("std");

// NOTE: In smart contract context don't really have to free memory before execution ends
var allocator = std.heap.wasm_allocator;

// Import host functions provided by NEAR runtime
extern fn input(register_id: u64) void;
extern fn signer_account_id(register_id: u64) void;
extern fn current_account_id(register_id: u64) void;
extern fn read_register(register_id: u64, ptr: u64) void;
extern fn register_len(register_id: u64) u64;
extern fn value_return(value_len: u64, value_ptr: u64) void;
extern fn log_utf8(len: u64, ptr: u64) void;
extern fn panic_utf8(len: u64, ptr: u64) void;
extern fn storage_has_key(key_len: u64, key_ptr: u64) u64;
extern fn storage_read(key_len: u64, key_ptr: u64, register_id: u64) u64;
extern fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, register_id: u64) u64;

const SCRATCH_REGISTER = 0xffffffff;
const OWNER_KEY = "owner";
const PALETTES_PREFIX = "palette:";
const PALETTE_COUNT_KEY = "palette_count";
const LIKES_PREFIX = "likes:";
const USER_LIKES_PREFIX = "user_likes:";

// Helper wrapper functions for interacting with the host
fn log(str: []const u8) void {
    log_utf8(str.len, @intFromPtr(str.ptr));
}

fn panic(str: []const u8) noreturn {
    panic_utf8(str.len, @intFromPtr(str.ptr));
    unreachable;
}

fn valueReturn(value: []const u8) void {
    value_return(value.len, @intFromPtr(value.ptr));
}

fn readRegisterLen(register_id: u64) u64 {
    return register_len(register_id);
}

fn readRegisterAlloc(register_id: u64) []const u8 {
    const len = readRegisterLen(register_id);
    if (len == 0) {
        return "";
    }
    const result = allocator.alloc(u8, @intCast(len)) catch panic("Failed to allocate memory");
    read_register(register_id, @intFromPtr(result.ptr));
    return result;
}

fn readInputAlloc() []const u8 {
    input(SCRATCH_REGISTER);
    return readRegisterAlloc(SCRATCH_REGISTER);
}

fn readSignerAccountId() []const u8 {
    signer_account_id(SCRATCH_REGISTER);
    return readRegisterAlloc(SCRATCH_REGISTER);
}

fn storageHasKey(key: []const u8) bool {
    return storage_has_key(key.len, @intFromPtr(key.ptr)) == 1;
}

fn storageRead(key: []const u8) ?[]const u8 {
    const res = storage_read(key.len, @intFromPtr(key.ptr), SCRATCH_REGISTER);
    return switch (res) {
        0 => null,
        1 => readRegisterAlloc(SCRATCH_REGISTER),
        else => null,
    };
}

fn storageWrite(key: []const u8, value: []const u8) bool {
    const res = storage_write(key.len, @intFromPtr(key.ptr), value.len, @intFromPtr(value.ptr), SCRATCH_REGISTER);
    return switch (res) {
        0 => false,
        1 => true,
        else => false,
    };
}

// Contract methods
export fn init() void {
    if (storageHasKey(OWNER_KEY)) {
        panic("Contract is already initialized");
    }
    const owner = readSignerAccountId();
    _ = storageWrite(OWNER_KEY, owner);
    _ = storageWrite(PALETTE_COUNT_KEY, "0");
    log("Contract initialized");
}

fn assertOwner() void {
    const owner = storageRead(OWNER_KEY) orelse panic("Contract not initialized");
    const signer = readSignerAccountId();
    if (!std.mem.eql(u8, owner, signer)) {
        panic("Only the owner can call this method");
    }
}

fn validateHexColor(color: []const u8) bool {
    if (color.len != 7 or color[0] != '#') return false;
    for (color[1..]) |c| {
        switch (c) {
            '0'...'9', 'A'...'F', 'a'...'f' => continue,
            else => return false,
        }
    }
    return true;
}

export fn add_palette() void {
    const input_str = readInputAlloc();
    const palette_input = std.json.parseFromSlice(struct {
        name: []const u8,
        colors: [][]const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer palette_input.deinit();

    if (palette_input.value.name.len == 0) panic("Name cannot be empty");
    if (palette_input.value.colors.len == 0) panic("Colors array cannot be empty");

    // Validate color codes
    for (palette_input.value.colors) |color| {
        if (!validateHexColor(color)) {
            panic("Invalid color code format");
        }
    }

    // Get and increment palette count
    const count_str = storageRead(PALETTE_COUNT_KEY) orelse "0";
    const count = std.fmt.parseInt(u32, count_str, 10) catch 0;
    const new_count = count + 1;

    // Create palette ID
    var id_buf: [32]u8 = undefined;
    const palette_id = std.fmt.bufPrint(&id_buf, "palette-{d}", .{new_count}) catch panic("Failed to create palette ID");

    // Store palette data
    var palette = std.ArrayList(u8).init(allocator);
    defer palette.deinit();

    const palette_data = .{
        .id = palette_id,
        .name = palette_input.value.name,
        .colors = palette_input.value.colors,
        .creator = readSignerAccountId(),
    };

    std.json.stringify(palette_data, .{}, palette.writer()) catch panic("Failed to serialize palette data");

    const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, palette_id }) catch panic("Failed to create palette key");
    defer allocator.free(palette_key);

    _ = storageWrite(palette_key, palette.items);
    _ = storageWrite(PALETTE_COUNT_KEY, std.fmt.bufPrint(&id_buf, "{d}", .{new_count}) catch panic("Failed to update count"));

    valueReturn(palette.items);
    log("Palette added successfully");
}

export fn remove_palette() void {
    assertOwner();

    const input_str = readInputAlloc();
    const remove_input = std.json.parseFromSlice(struct {
        id: []const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer remove_input.deinit();

    const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, remove_input.value.id }) catch panic("Failed to create palette key");
    defer allocator.free(palette_key);

    if (!storageHasKey(palette_key)) {
        panic("Palette not found");
    }

    _ = storageWrite(palette_key, ""); // Delete by writing empty value
    log("Palette removed successfully");
}

export fn get_palettes() void {
    const count_str = storageRead(PALETTE_COUNT_KEY) orelse "0";
    const count = std.fmt.parseInt(u32, count_str, 10) catch 0;

    var palettes = std.ArrayList(u8).init(allocator);
    defer palettes.deinit();

    // Start JSON array
    palettes.appendSlice("[") catch panic("Failed to create JSON array");
    var first = true;

    var i: u32 = 1;
    while (i <= count) : (i += 1) {
        var id_buf: [32]u8 = undefined;
        const palette_id = std.fmt.bufPrint(&id_buf, "palette-{d}", .{i}) catch continue;
        const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, palette_id }) catch continue;
        defer allocator.free(palette_key);

        if (storageRead(palette_key)) |palette_data| {
            if (palette_data.len > 0) {
                if (!first) {
                    palettes.appendSlice(",") catch panic("Failed to append separator");
                }
                palettes.appendSlice(palette_data) catch panic("Failed to append palette data");
                first = false;
            }
        }
    }

    // Close JSON array
    palettes.appendSlice("]") catch panic("Failed to close JSON array");
    valueReturn(palettes.items);
}

export fn get_palette_by_id() void {
    const input_str = readInputAlloc();
    const id_input = std.json.parseFromSlice(struct {
        id: []const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer id_input.deinit();

    const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, id_input.value.id }) catch panic("Failed to create palette key");
    defer allocator.free(palette_key);

    if (storageRead(palette_key)) |palette_data| {
        if (palette_data.len > 0) {
            valueReturn(palette_data);
            return;
        }
    }

    valueReturn("null");
}

export fn like_palette() void {
    const input_str = readInputAlloc();
    const like_input = std.json.parseFromSlice(struct {
        palette_id: []const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer like_input.deinit();

    const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, like_input.value.palette_id }) catch panic("Failed to create palette key");
    defer allocator.free(palette_key);

    if (!storageHasKey(palette_key)) {
        panic("Palette not found");
    }

    const user_id = readSignerAccountId();
    const user_like_key = std.fmt.allocPrint(allocator, "{s}{s}:{s}", .{ USER_LIKES_PREFIX, user_id, like_input.value.palette_id }) catch panic("Failed to create user like key");
    defer allocator.free(user_like_key);

    if (storageHasKey(user_like_key)) {
        panic("User has already liked this palette");
    }

    const likes_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ LIKES_PREFIX, like_input.value.palette_id }) catch panic("Failed to create likes key");
    defer allocator.free(likes_key);

    const current_likes_str = storageRead(likes_key) orelse "0";
    const current_likes = std.fmt.parseInt(u32, current_likes_str, 10) catch 0;
    const new_likes = current_likes + 1;

    var likes_buf: [32]u8 = undefined;
    const new_likes_str = std.fmt.bufPrint(&likes_buf, "{d}", .{new_likes}) catch panic("Failed to convert likes count");

    _ = storageWrite(likes_key, new_likes_str);
    _ = storageWrite(user_like_key, "1");

    log("Palette liked successfully");
}

export fn unlike_palette() void {
    const input_str = readInputAlloc();
    const unlike_input = std.json.parseFromSlice(struct {
        palette_id: []const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer unlike_input.deinit();

    const palette_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ PALETTES_PREFIX, unlike_input.value.palette_id }) catch panic("Failed to create palette key");
    defer allocator.free(palette_key);

    if (!storageHasKey(palette_key)) {
        panic("Palette not found");
    }

    const user_id = readSignerAccountId();
    const user_like_key = std.fmt.allocPrint(allocator, "{s}{s}:{s}", .{ USER_LIKES_PREFIX, user_id, unlike_input.value.palette_id }) catch panic("Failed to create user like key");
    defer allocator.free(user_like_key);

    if (!storageHasKey(user_like_key)) {
        panic("User has not liked this palette");
    }

    const likes_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ LIKES_PREFIX, unlike_input.value.palette_id }) catch panic("Failed to create likes key");
    defer allocator.free(likes_key);

    const current_likes_str = storageRead(likes_key) orelse "0";
    const current_likes = std.fmt.parseInt(u32, current_likes_str, 10) catch 0;
    const new_likes = if (current_likes > 0) current_likes - 1 else 0;

    var likes_buf: [32]u8 = undefined;
    const new_likes_str = std.fmt.bufPrint(&likes_buf, "{d}", .{new_likes}) catch panic("Failed to convert likes count");

    _ = storageWrite(likes_key, new_likes_str);
    _ = storageWrite(user_like_key, ""); // Remove the user's like

    log("Palette unliked successfully");
}

export fn get_likes() void {
    const input_str = readInputAlloc();
    const likes_input = std.json.parseFromSlice(struct {
        palette_id: []const u8,
    }, allocator, input_str, .{}) catch panic("Invalid JSON input");
    defer likes_input.deinit();

    const likes_key = std.fmt.allocPrint(allocator, "{s}{s}", .{ LIKES_PREFIX, likes_input.value.palette_id }) catch panic("Failed to create likes key");
    defer allocator.free(likes_key);

    const likes_str = storageRead(likes_key) orelse "0";
    valueReturn(likes_str);
}
