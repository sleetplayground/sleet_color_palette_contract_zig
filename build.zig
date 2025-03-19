const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    // Main WASM artifact
    const color_palette_lib = b.addExecutable(.{
        .name = "color_palette",
        .root_source_file = b.path("color_palette.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
    });

    // Enable link-time optimization
    color_palette_lib.want_lto = true;

    // Don't need start function for WASM
    color_palette_lib.entry = .disabled;

    // Export the required functions
    color_palette_lib.root_module.export_symbol_names = &[_][]const u8{
        "init",
        "add_palette",
        "remove_palette",
        "get_palettes",
        "get_palette_by_id",
        "like_palette",
        "unlike_palette",
        "get_likes",
    };

    b.installArtifact(color_palette_lib);

    // Unit tests - use native target for testing
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("color_palette.test.zig"),
        // Use native target for tests, not WASM
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Create a step for running the tests
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
