const std = @import("std");

const lmdb_root = "libraries/liblmdb";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("lmdb_upstream", .{});
    const lmdb_dir = upstream.path(lmdb_root);
    const mdb_flags: []const []const u8 = if (target.result.os.tag == .macos)
        &.{
            "-pthread",
            "-std=c99",
            "-D_XOPEN_SOURCE=600",
            "-DMDB_USE_POSIX_SEM=1",
        }
    else
        &.{
            "-pthread",
            "-std=c99",
            "-D_XOPEN_SOURCE=600",
        };

    const liblmdb = b.addLibrary(.{
        .name = "lmdb",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    liblmdb.root_module.link_libc = true;
    liblmdb.root_module.addCSourceFile(.{
        .file = upstream.path(lmdb_root ++ "/mdb.c"),
        .flags = mdb_flags,
    });
    liblmdb.root_module.addCSourceFile(.{
        .file = upstream.path(lmdb_root ++ "/midl.c"),
        .flags = &.{
            "-pthread",
            "-std=c99",
            "-D_XOPEN_SOURCE=600",
        },
    });
    liblmdb.root_module.addIncludePath(lmdb_dir);

    if (target.result.os.tag == .macos) {
        liblmdb.root_module.addCMacro("_DARWIN_C_SOURCE", "");
    }

    liblmdb.installHeader(upstream.path(lmdb_root ++ "/lmdb.h"), "lmdb.h");
    liblmdb.installHeader(upstream.path(lmdb_root ++ "/midl.h"), "midl.h");
    b.installArtifact(liblmdb);

    const tools_step = b.step("tools", "Build LMDB tools");
    const tool_names = &[_][]const u8{
        "mdb_copy",
        "mdb_drop",
        "mdb_dump",
        "mdb_load",
        "mdb_stat",
    };

    for (tool_names) |tool_name| {
        const tool = b.addExecutable(.{
            .name = tool_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        tool.root_module.link_libc = true;
        tool.root_module.addCSourceFile(.{
            .file = upstream.path(b.fmt("{s}/{s}.c", .{ lmdb_root, tool_name })),
            .flags = &.{
                "-pthread",
                "-std=c99",
                "-D_XOPEN_SOURCE=600",
            },
        });
        tool.root_module.addIncludePath(lmdb_dir);
        tool.root_module.linkLibrary(liblmdb);

        if (target.result.os.tag == .macos) {
            tool.root_module.addCMacro("_DARWIN_C_SOURCE", "");
        }

        const install_tool = b.addInstallArtifact(tool, .{});
        tools_step.dependOn(&install_tool.step);
    }

    const test_step = b.step("test", "Run LMDB tests");
    const test_names = &[_][]const u8{
        "mtest",
        "mtest2",
        "mtest3",
        "mtest4",
        "mtest5",
    };

    for (test_names) |test_name| {
        const test_exe = b.addExecutable(.{
            .name = test_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = .Debug,
            }),
        });

        test_exe.root_module.link_libc = true;
        test_exe.root_module.addCSourceFile(.{
            .file = upstream.path(b.fmt("{s}/{s}.c", .{ lmdb_root, test_name })),
            .flags = &.{
                "-pthread",
                "-std=c99",
                "-Wno-format",
                "-Wno-implicit-function-declaration",
            },
        });
        test_exe.root_module.addIncludePath(lmdb_dir);
        test_exe.root_module.linkLibrary(liblmdb);

        const run = b.addRunArtifact(test_exe);
        test_step.dependOn(&run.step);
    }
}
