const std = @import("std");
const testing = std.testing;

pub fn RefCounter(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        count: usize,
        ptr: *T,
        destroyed: bool,

        const Error = error {
            AlreadyDestroyed
        };

        fn create(allocator: std.mem.Allocator, value: T) !@This() {
            var ptr = try allocator.create(T);
            ptr.* = value;
            return RefCounter(T).init(allocator, ptr);
        }

        fn init(allocator: std.mem.Allocator, ptr: *T) @This() {
            return .{
                .allocator = allocator,
                .count = 1,
                .ptr = ptr,
                .destroyed = false,
            };
        }

        fn deinit(self: *@This()) void {
            self.count -= 1;
            if (self.count <= 0 and self.destroyed == false){
                self.destroy();
            }
        }

        fn use(self: *@This()) !*RefCounter(T) {
            if (self.destroyed){
                return Error.AlreadyDestroyed;
            }
            self.count += 1;
            return self;
        }

        fn isDestroyed(self: *@This()) bool {
            return self.destroyed;
        }

        fn get(self: *@This()) !*T {
            if (self.destroyed){
                return Error.AlreadyDestroyed;
            }
            return self.ptr;
        }

        fn getOrNull(self: *@This()) ?*T {
            if (self.destroyed){
                return null;
            }
            return self.ptr;
        }

        fn reset(self: *@This(), ptr: *T) void {
            self.count = 1;
            self.destroyed = false;
            self.allocator.destroy(self.ptr);
            self.ptr = ptr;
        }

        fn destroy(self: *@This()) void {
            self.destroyed = true;
            self.allocator.destroy(self.ptr);
        }
    };
}

test "test" {
    var allocator = testing.allocator;
    
    var a1 = try RefCounter([]const u8).create(allocator, "bamiyan");
    try testing.expect(std.mem.eql(u8, a1.ptr.*, "bamiyan"));
    {
        var a2 = try a1.use();
        defer a2.deinit();
        try testing.expect(a2.count == 2);
        a2.ptr.* = "gusto";
    }
    try testing.expect(a1.count == 1);
    try testing.expect(std.mem.eql(u8, a1.ptr.*, "gusto"));
    a1.deinit();
    try testing.expect(a1.count == 0);
    try testing.expect(a1.destroyed == true);
}
