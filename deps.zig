const std = @import("std");
pub const pkgs = struct {
    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        @setEvalBranchQuota(1_000_000);
        inline for (std.meta.declarations(@This())) |decl| {
            if (decl.is_pub and decl.data == .Var) {
                artifact.addPackage(@field(@This(), decl.name));
            }
        }
    }
};
