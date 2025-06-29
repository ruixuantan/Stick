const std = @import("std");
const Datatype = @import("datatype.zig").Datatype;

pub const Field = struct { name: []const u8, datatype: Datatype };

pub const Schema = struct {
    const SchemaError = error{SchemaFieldAlreadyExists};

    fields: std.ArrayList(Field),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Schema {
        const fields = std.ArrayList(Field).init(allocator);
        return .{ .fields = fields, .allocator = allocator };
    }

    pub fn deinit(self: Schema) void {
        for (self.fields.items) |field| {
            self.allocator.free(field.name);
        }
        self.fields.deinit();
    }

    fn containsDuplicates(self: Schema, name: []const u8) bool {
        for (self.fields.items) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                return true;
            }
        }
        return false;
    }

    pub fn add(self: *Schema, name: []const u8, datatype: Datatype) !void {
        if (self.containsDuplicates(name)) {
            return SchemaError.SchemaFieldAlreadyExists;
        }
        const field = Field{ .name = try self.allocator.dupe(u8, name), .datatype = datatype };
        try self.fields.append(field);
    }
};
