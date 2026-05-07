const std = @import("std");
const std_compat = @import("compat");
const paths_mod = @import("paths.zig");
const state_mod = @import("state.zig");
const test_helpers = @import("../test_helpers.zig");

pub const NullTicketsConfig = struct {
    name: []const u8,
    port: u16 = 7700,
    api_token: ?[]const u8 = null,
};

pub const NullWatchConfig = struct {
    name: []const u8,
    host: []const u8 = "127.0.0.1",
    port: u16 = 7710,
    api_token: ?[]const u8 = null,
};

pub const NullBoilerWorkflowConfig = struct {
    file_name: []const u8,
    pipeline_id: []const u8,
    claim_role: []const u8,
    success_trigger: []const u8,
};

pub const managed_workflow_file_name = "nullhub-tracker-workflow.json";
pub const legacy_workflow_file_name = "tracker-workflow.json";

pub const NullBoilerTrackerConfig = struct {
    url: []const u8,
    api_token: ?[]const u8 = null,
    agent_id: []const u8 = "nullboiler",
    workflows_dir: []const u8 = "workflows",
    max_concurrent_tasks: u32 = 10,
    workflow: ?NullBoilerWorkflowConfig = null,
};

pub const NullBoilerConfig = struct {
    name: []const u8,
    port: u16 = 8080,
    api_token: ?[]const u8 = null,
    tracker: ?NullBoilerTrackerConfig = null,
};

pub const NullClawTelemetryLink = struct {
    configured: bool = false,
    endpoint: ?[]u8 = null,
    service_name: ?[]u8 = null,
    auth_configured: bool = false,
    source_header_configured: bool = false,

    pub fn deinit(self: *NullClawTelemetryLink, allocator: std.mem.Allocator) void {
        if (self.endpoint) |value| allocator.free(value);
        if (self.service_name) |value| allocator.free(value);
        self.* = .{};
    }
};

pub fn listNullTickets(allocator: std.mem.Allocator, state: *state_mod.State, paths: paths_mod.Paths) ![]NullTicketsConfig {
    const names = try state.instanceNames("nulltickets") orelse return allocator.alloc(NullTicketsConfig, 0);
    defer state.allocator.free(names);
    var list: std.ArrayListUnmanaged(NullTicketsConfig) = .empty;
    errdefer deinitNullTicketsConfigs(allocator, list.items);
    defer list.deinit(allocator);

    for (names) |name| {
        if (try loadNullTicketsConfig(allocator, paths, name)) |cfg| {
            var owned = cfg;
            errdefer deinitNullTicketsConfig(allocator, &owned);
            try list.append(allocator, owned);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn listNullWatch(allocator: std.mem.Allocator, state: *state_mod.State, paths: paths_mod.Paths) ![]NullWatchConfig {
    const names = try state.instanceNames("nullwatch") orelse return allocator.alloc(NullWatchConfig, 0);
    defer state.allocator.free(names);
    var list: std.ArrayListUnmanaged(NullWatchConfig) = .empty;
    errdefer deinitNullWatchConfigs(allocator, list.items);
    defer list.deinit(allocator);

    for (names) |name| {
        if (try loadNullWatchConfig(allocator, paths, name)) |cfg| {
            var owned = cfg;
            errdefer deinitNullWatchConfig(allocator, &owned);
            try list.append(allocator, owned);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn listNullBoilers(allocator: std.mem.Allocator, state: *state_mod.State, paths: paths_mod.Paths) ![]NullBoilerConfig {
    const names = try state.instanceNames("nullboiler") orelse return allocator.alloc(NullBoilerConfig, 0);
    defer state.allocator.free(names);
    var list: std.ArrayListUnmanaged(NullBoilerConfig) = .empty;
    errdefer deinitNullBoilerConfigs(allocator, list.items);
    defer list.deinit(allocator);

    for (names) |name| {
        if (try loadNullBoilerConfig(allocator, paths, name)) |cfg| {
            var owned = cfg;
            errdefer deinitNullBoilerConfig(allocator, &owned);
            try list.append(allocator, owned);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn loadNullTicketsConfig(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !?NullTicketsConfig {
    const config_path = paths.instanceConfig(allocator, "nulltickets", name) catch return null;
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(NullTicketsConfigFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    return .{
        .name = try allocator.dupe(u8, name),
        .port = parsed.value.port,
        .api_token = if (parsed.value.api_token) |token| try allocator.dupe(u8, token) else null,
    };
}

pub fn loadNullWatchConfig(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !?NullWatchConfig {
    const config_path = paths.instanceConfig(allocator, "nullwatch", name) catch return null;
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(NullWatchConfigFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    return .{
        .name = try allocator.dupe(u8, name),
        .host = try allocator.dupe(u8, parsed.value.host),
        .port = parsed.value.port,
        .api_token = if (parsed.value.api_token) |token| try allocator.dupe(u8, token) else null,
    };
}

pub fn loadNullBoilerConfig(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !?NullBoilerConfig {
    const config_path = paths.instanceConfig(allocator, "nullboiler", name) catch return null;
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(NullBoilerConfigFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    const config_dir = std.fs.path.dirname(config_path) orelse return null;

    var cfg = NullBoilerConfig{
        .name = try allocator.dupe(u8, name),
        .port = parsed.value.port,
        .api_token = if (parsed.value.api_token) |token| try allocator.dupe(u8, token) else null,
    };
    errdefer deinitNullBoilerConfig(allocator, &cfg);

    if (parsed.value.tracker) |tracker| {
        var tracker_cfg = NullBoilerTrackerConfig{
            .url = try allocator.dupe(u8, tracker.url orelse ""),
            .api_token = if (tracker.api_token) |token| try allocator.dupe(u8, token) else null,
            .agent_id = try allocator.dupe(u8, tracker.agent_id),
            .workflows_dir = try resolveRelativePath(allocator, config_dir, tracker.workflows_dir),
            .max_concurrent_tasks = tracker.concurrency.max_concurrent_tasks,
        };
        errdefer {
            allocator.free(tracker_cfg.url);
            if (tracker_cfg.api_token) |token| allocator.free(token);
            allocator.free(tracker_cfg.agent_id);
            allocator.free(tracker_cfg.workflows_dir);
            if (tracker_cfg.workflow) |*workflow| {
                allocator.free(workflow.file_name);
                allocator.free(workflow.pipeline_id);
                allocator.free(workflow.claim_role);
                allocator.free(workflow.success_trigger);
            }
        }
        tracker_cfg.workflow = try loadPrimaryWorkflowConfig(allocator, tracker_cfg.workflows_dir);
        cfg.tracker = tracker_cfg;
    }

    return cfg;
}

pub fn deinitNullTicketsConfig(allocator: std.mem.Allocator, cfg: *NullTicketsConfig) void {
    allocator.free(cfg.name);
    if (cfg.api_token) |token| allocator.free(token);
    cfg.* = undefined;
}

pub fn deinitNullTicketsConfigs(allocator: std.mem.Allocator, configs: []NullTicketsConfig) void {
    for (configs) |*cfg| deinitNullTicketsConfig(allocator, cfg);
    allocator.free(configs);
}

pub fn deinitNullWatchConfig(allocator: std.mem.Allocator, cfg: *NullWatchConfig) void {
    allocator.free(cfg.name);
    allocator.free(cfg.host);
    if (cfg.api_token) |token| allocator.free(token);
    cfg.* = undefined;
}

pub fn deinitNullWatchConfigs(allocator: std.mem.Allocator, configs: []NullWatchConfig) void {
    for (configs) |*cfg| deinitNullWatchConfig(allocator, cfg);
    allocator.free(configs);
}

pub fn deinitNullBoilerConfig(allocator: std.mem.Allocator, cfg: *NullBoilerConfig) void {
    allocator.free(cfg.name);
    if (cfg.api_token) |token| allocator.free(token);
    if (cfg.tracker) |*tracker| {
        allocator.free(tracker.url);
        if (tracker.api_token) |token| allocator.free(token);
        allocator.free(tracker.agent_id);
        allocator.free(tracker.workflows_dir);
        if (tracker.workflow) |*workflow| {
            allocator.free(workflow.file_name);
            allocator.free(workflow.pipeline_id);
            allocator.free(workflow.claim_role);
            allocator.free(workflow.success_trigger);
        }
    }
    cfg.* = undefined;
}

pub fn deinitNullBoilerConfigs(allocator: std.mem.Allocator, configs: []NullBoilerConfig) void {
    for (configs) |*cfg| deinitNullBoilerConfig(allocator, cfg);
    allocator.free(configs);
}

pub fn matchNullTicketsTarget(boiler_cfg: NullBoilerConfig, tickets: []const NullTicketsConfig) ?NullTicketsConfig {
    const tracker = boiler_cfg.tracker orelse return null;
    const tracker_port = extractLocalPort(tracker.url) orelse return null;

    for (tickets) |ticket| {
        if (ticket.port == tracker_port) return ticket;
    }
    return null;
}

pub fn countLinkedBoilersForTickets(tickets_cfg: NullTicketsConfig, boilers: []const NullBoilerConfig) usize {
    var count: usize = 0;
    for (boilers) |boiler| {
        const target = matchNullTicketsTarget(boiler, &.{tickets_cfg}) orelse continue;
        _ = target;
        count += 1;
    }
    return count;
}

pub fn loadNullClawTelemetryLink(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !NullClawTelemetryLink {
    const config_path = try paths.instanceConfig(allocator, "nullclaw", name);
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.NotFound,
        else => return err,
    };
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    return try parseNullClawTelemetryLink(allocator, parsed.value);
}

pub fn linkNullClawToNullWatch(
    allocator: std.mem.Allocator,
    paths: paths_mod.Paths,
    claw_name: []const u8,
    watch_cfg: NullWatchConfig,
) !void {
    const config_path = try paths.instanceConfig(allocator, "nullclaw", claw_name);
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.NotFound,
        else => return err,
    };
    defer file.close();

    const config_bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(config_bytes);

    var parsed_config = try std.json.parseFromSlice(std.json.Value, allocator, config_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
    defer parsed_config.deinit();
    if (parsed_config.value != .object) return error.InvalidConfig;

    const diagnostics_map = try ensureObjectField(allocator, &parsed_config.value.object, "diagnostics");
    try diagnostics_map.put(allocator, "backend", .{ .string = "otel" });

    const otel_map = try ensureObjectField(allocator, diagnostics_map, "otel");
    const endpoint = try buildNullWatchEndpoint(allocator, watch_cfg);
    try otel_map.put(allocator, "endpoint", .{ .string = endpoint });

    const should_default_service = blk: {
        const service_name = jsonString(otel_map.*, "service_name") orelse break :blk true;
        break :blk service_name.len == 0 or std.mem.eql(u8, service_name, "nullclaw");
    };
    if (should_default_service) {
        const service_name = try std.fmt.allocPrint(allocator, "nullclaw/{s}", .{claw_name});
        try otel_map.put(allocator, "service_name", .{ .string = service_name });
    }

    const headers_map = try ensureObjectField(allocator, otel_map, "headers");
    try headers_map.put(allocator, "x-nullwatch-source", .{ .string = "nullclaw" });
    if (watch_cfg.api_token) |token| {
        const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{token});
        try headers_map.put(allocator, "Authorization", .{ .string = auth_header });
    } else {
        _ = headers_map.swapRemove("Authorization");
    }

    const rendered = try std.json.Stringify.valueAlloc(allocator, parsed_config.value, .{
        .whitespace = .indent_2,
        .emit_null_optional_fields = false,
    });
    defer allocator.free(rendered);

    const out = try std_compat.fs.createFileAbsolute(config_path, .{ .truncate = true });
    defer out.close();
    try out.writeAll(rendered);
    try out.writeAll("\n");
}

pub fn findNullWatchByEndpoint(watches: []const NullWatchConfig, endpoint: ?[]const u8) ?NullWatchConfig {
    const value = endpoint orelse return null;
    const port = nullWatchEndpointPort(value) orelse return null;
    for (watches) |watch| {
        if (watch.port == port) return watch;
    }
    return null;
}

pub fn buildNullWatchEndpoint(allocator: std.mem.Allocator, watch: NullWatchConfig) ![]u8 {
    const host = normalizedConnectHost(watch.host);
    if (std.mem.indexOfScalar(u8, host, ':') != null and !std.mem.startsWith(u8, host, "[")) {
        return std.fmt.allocPrint(allocator, "http://[{s}]:{d}", .{ host, watch.port });
    }
    return std.fmt.allocPrint(allocator, "http://{s}:{d}", .{ host, watch.port });
}

pub fn extractLocalPort(url: []const u8) ?u16 {
    const uri = std.Uri.parse(url) catch return null;
    const host = uri.host orelse return null;
    const port = uri.port orelse return null;

    return switch (host) {
        .raw => |value| if (isLocalHost(value)) port else null,
        else => null,
    };
}

fn parseNullClawTelemetryLink(allocator: std.mem.Allocator, config: std.json.Value) !NullClawTelemetryLink {
    const diagnostics = diagnosticsObject(config) orelse return .{};
    const backend = jsonString(diagnostics, "backend") orelse "";
    const backend_configured = std.mem.eql(u8, backend, "otel") or std.mem.eql(u8, backend, "otlp");

    var endpoint: ?[]const u8 = null;
    var service_name: ?[]const u8 = null;
    if (objectField(diagnostics, "otel")) |otel| {
        endpoint = jsonString(otel, "endpoint");
        service_name = jsonString(otel, "service_name");
    }

    const headers = telemetryHeadersObject(diagnostics);
    const auth_configured = if (headers) |map| jsonString(map, "Authorization") != null else false;
    const source_header_configured = if (headers) |map| jsonString(map, "x-nullwatch-source") != null else false;

    return .{
        .configured = backend_configured and endpoint != null,
        .endpoint = if (endpoint) |value| try allocator.dupe(u8, value) else null,
        .service_name = if (service_name) |value| try allocator.dupe(u8, value) else null,
        .auth_configured = auth_configured,
        .source_header_configured = source_header_configured,
    };
}

fn objectField(obj: std.json.ObjectMap, key: []const u8) ?std.json.ObjectMap {
    const value = obj.get(key) orelse return null;
    return if (value == .object) value.object else null;
}

fn diagnosticsObject(config: std.json.Value) ?std.json.ObjectMap {
    if (config != .object) return null;
    return objectField(config.object, "diagnostics");
}

fn telemetryHeadersObject(diagnostics: std.json.ObjectMap) ?std.json.ObjectMap {
    if (objectField(diagnostics, "otel")) |otel| {
        if (objectField(otel, "headers")) |headers| return headers;
    }
    return null;
}

fn nullWatchEndpointPort(endpoint: []const u8) ?u16 {
    if (extractLocalPort(endpoint)) |port| return port;
    const uri = std.Uri.parse(endpoint) catch return null;
    return uri.port;
}

fn normalizedConnectHost(host: []const u8) []const u8 {
    if (host.len == 0 or
        std.mem.eql(u8, host, "0.0.0.0") or
        std.mem.eql(u8, host, "::") or
        std.mem.eql(u8, host, "[::]") or
        std.mem.eql(u8, host, "localhost"))
    {
        return "127.0.0.1";
    }
    return host;
}

fn isLocalHost(host: []const u8) bool {
    return std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "localhost") or
        std.mem.eql(u8, host, "0.0.0.0") or
        std.mem.eql(u8, host, "::1");
}

fn jsonString(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = obj.get(key) orelse return null;
    return if (value == .string) value.string else null;
}

fn ensureObjectField(
    allocator: std.mem.Allocator,
    parent: *std.json.ObjectMap,
    key: []const u8,
) !*std.json.ObjectMap {
    if (parent.getPtr(key)) |value_ptr| {
        if (value_ptr.* != .object) {
            value_ptr.* = .{ .object = .empty };
        }
        return &value_ptr.object;
    }

    try parent.put(allocator, key, .{ .object = .empty });
    return &parent.getPtr(key).?.object;
}

fn loadPrimaryWorkflowConfig(allocator: std.mem.Allocator, workflows_dir: []const u8) !?NullBoilerWorkflowConfig {
    var dir = std_compat.fs.openDirAbsolute(workflows_dir, .{ .iterate = true }) catch return null;
    defer dir.close();

    const managed_path = try std.fs.path.join(allocator, &.{ workflows_dir, managed_workflow_file_name });
    defer allocator.free(managed_path);
    if (std_compat.fs.openFileAbsolute(managed_path, .{})) |managed_file| {
        managed_file.close();
        return loadWorkflowConfigFromFile(allocator, workflows_dir, managed_workflow_file_name);
    } else |_| {}

    var best_name: ?[]const u8 = null;
    defer if (best_name) |value| allocator.free(value);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        if (best_name == null or std.mem.order(u8, entry.name, best_name.?) == .lt) {
            if (best_name) |value| allocator.free(value);
            best_name = try allocator.dupe(u8, entry.name);
        }
    }

    const file_name = best_name orelse return null;
    return loadWorkflowConfigFromFile(allocator, workflows_dir, file_name);
}

fn loadWorkflowConfigFromFile(allocator: std.mem.Allocator, workflows_dir: []const u8, file_name: []const u8) !?NullBoilerWorkflowConfig {
    const workflow_path = try std.fs.path.join(allocator, &.{ workflows_dir, file_name });
    defer allocator.free(workflow_path);
    const file = std_compat.fs.openFileAbsolute(workflow_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(WorkflowFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    const file_name_owned = try allocator.dupe(u8, file_name);
    errdefer allocator.free(file_name_owned);
    const pipeline_id = try allocator.dupe(u8, parsed.value.pipeline_id);
    errdefer allocator.free(pipeline_id);
    const claim_role = try allocator.dupe(u8, if (parsed.value.claim_roles.len > 0) parsed.value.claim_roles[0] else "");
    errdefer allocator.free(claim_role);
    const success_trigger = try allocator.dupe(u8, if (parsed.value.on_success) |cfg| cfg.transition_to else "");

    return .{
        .file_name = file_name_owned,
        .pipeline_id = pipeline_id,
        .claim_role = claim_role,
        .success_trigger = success_trigger,
    };
}

fn resolveRelativePath(allocator: std.mem.Allocator, base_dir: []const u8, value: []const u8) ![]const u8 {
    if (value.len == 0 or std.fs.path.isAbsolute(value)) return allocator.dupe(u8, value);
    return std.fs.path.resolve(allocator, &.{ base_dir, value });
}

const NullTicketsConfigFile = struct {
    port: u16 = 7700,
    api_token: ?[]const u8 = null,
};

const NullWatchConfigFile = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 7710,
    api_token: ?[]const u8 = null,
};

const NullBoilerConfigFile = struct {
    port: u16 = 8080,
    api_token: ?[]const u8 = null,
    tracker: ?struct {
        url: ?[]const u8 = null,
        api_token: ?[]const u8 = null,
        agent_id: []const u8 = "nullboiler",
        concurrency: struct {
            max_concurrent_tasks: u32 = 10,
        } = .{},
        workflows_dir: []const u8 = "workflows",
    } = null,
};

const WorkflowFile = struct {
    pipeline_id: []const u8,
    claim_roles: []const []const u8 = &.{},
    on_success: ?struct {
        transition_to: []const u8 = "",
    } = null,
};

test "loadNullBoilerConfig accepts tracker without url" {
    const allocator = std.testing.allocator;
    var fixture = try test_helpers.TempPaths.init(allocator);
    defer fixture.deinit();
    try fixture.paths.ensureDirs();

    const inst_dir = try fixture.paths.instanceDir(allocator, "nullboiler", "worker-a");
    defer allocator.free(inst_dir);
    try std.fs.makePathAbsolute(inst_dir);

    const config_path = try fixture.paths.instanceConfig(allocator, "nullboiler", "worker-a");
    defer allocator.free(config_path);
    const file = try std_compat.fs.createFileAbsolute(config_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll("{\"port\":8811,\"tracker\":{\"agent_id\":\"worker-a\"}}\n");

    var cfg = (try loadNullBoilerConfig(allocator, fixture.paths, "worker-a")).?;
    defer deinitNullBoilerConfig(allocator, &cfg);

    try std.testing.expectEqual(@as(u16, 8811), cfg.port);
    try std.testing.expect(cfg.tracker != null);
    try std.testing.expectEqualStrings("", cfg.tracker.?.url);
    try std.testing.expectEqualStrings("worker-a", cfg.tracker.?.agent_id);
}
