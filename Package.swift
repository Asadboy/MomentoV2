// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Momento",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "Momento",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Auth", package: "supabase-swift"),
                .product(name: "PostgREST", package: "supabase-swift"),
                .product(name: "Storage", package: "supabase-swift"),
                .product(name: "Realtime", package: "supabase-swift")
            ]
        )
    ]
)

